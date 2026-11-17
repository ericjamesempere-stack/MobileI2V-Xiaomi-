import importlib.util
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('karma_supervisor',ROOT/'autopilot/supervisor.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class SupervisorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root/'scripts').mkdir()
        (self.root/'scripts/core.gd').write_text('extends RefCounted\n')
        (self.root/'tests').mkdir()
        (self.root/'tests/test_reference_review_pipeline.gd').write_text('extends SceneTree\n')
        self.state = self.root/'memory.sqlite3'
        self.reports = self.root/'reports'
        self.calls = 0
    def tearDown(self):
        self.temp.cleanup()
    def task(self,**extra):
        return dict(id='approval',agent='approval',executor='godot',test='approval',dependencies=[],**extra)
    def process(self,argv,cwd,timeout):
        if 'rev-parse' in argv:
            return subprocess.CompletedProcess(argv,0,'a'*40+'\n','')
        self.calls += 1
        return subprocess.CompletedProcess(argv,0,'REFERENCE_IMPORT_SUBJECT_PROMPT_AND_REVIEW_GATE_OK','')
    def sup(self,process=None):
        s = m.Supervisor(self.root,self.state,self.reports,process=process or self.process)
        s.tool=lambda name:('/synthetic/'+name,'toolhash')
        return s
    def test_dag_toposort_cycle_and_unknown_fail_closed(self):
        a=self.task(); b=dict(id='second',agent='qa',dependencies=['approval'])
        self.assertEqual([t['id'] for t in m.validate_tasks([b,a],{'qa','approval'})],['approval','second'])
        a['dependencies']=['second']
        with self.assertRaisesRegex(ValueError,'cycle'): m.validate_tasks([a,b],{'qa','approval'})
        with self.assertRaisesRegex(ValueError,'unknown_dependency'): m.validate_tasks([b],{'qa'})
    def test_task_cannot_execute_shell_or_arbitrary_test(self):
        for task in [dict(self.task(),command='rm -rf anything'),dict(self.task(),test='../evil.gd'),dict(self.task(),max_attempts=3),dict(self.task(),privacy_class='private')]:
            with self.assertRaises(ValueError): m.validate_tasks([task],{'approval'})
    def test_success_cache_survives_restart_and_input_change_invalidates(self):
        s=self.sup(); self.assertEqual(s.run([self.task()])['approval']['status'],'PASS'); s.memory.close()
        count=self.calls
        s=self.sup(); self.assertTrue(s.run([self.task()])['approval']['cached']); s.memory.close()
        self.assertEqual(self.calls,count)
        (self.root/'scripts/core.gd').write_text('extends Node\n')
        s=self.sup(); r=s.run([self.task()])['approval']; s.memory.close()
        self.assertFalse(r.get('cached',False)); self.assertEqual(self.calls,count+1)
    def test_tampered_evidence_invalidates_cache(self):
        s=self.sup(); r=s.run([self.task()])['approval']; s.memory.close()
        Path(r['artifacts'][0]['path']).write_text('tampered')
        count=self.calls
        s=self.sup(); self.assertFalse(s.run([self.task()])['approval'].get('cached',False)); s.memory.close()
        self.assertEqual(self.calls,count+1)
    def test_input_artifact_content_changes_key(self):
        s=self.sup(); p=self.root/'synthetic.mp4'; p.write_bytes(b'one'); s.artifacts={'mp4':p}
        t=dict(id='video',agent='video',executor='video',artifact='mp4')
        first=s.key(t); p.write_bytes(b'two'); self.assertNotEqual(first,s.key(t)); s.memory.close()
    def test_two_failed_attempts_persist_and_errors_exit_zero_fail(self):
        def error(argv,cwd,timeout):
            if 'rev-parse' in argv: return self.process(argv,cwd,timeout)
            self.calls+=1
            return subprocess.CompletedProcess(argv,0,'REFERENCE_IMPORT_SUBJECT_PROMPT_AND_REVIEW_GATE_OK\nSCRIPT ERROR: secret-token-private-prompt','')
        for _ in range(2):
            s=self.sup(error); r=s.run([self.task()])['approval']; self.assertEqual(r['status'],'FAIL'); s.memory.close()
        count=self.calls
        s=self.sup(error); r=s.run([self.task()])['approval']; self.assertEqual(r['reason'],'attempt_budget_exhausted'); s.memory.close()
        self.assertEqual(self.calls,count)
        self.assertNotIn(b'secret-token-private-prompt',self.state.read_bytes())
        self.assertNotIn('secret-token-private-prompt',(self.reports/'latest.json').read_text())
    def test_dependency_failure_never_runs_dependent(self):
        s=self.sup(); tasks=[dict(id='vision',agent='vision',executor='unconnected'),dict(self.task(),dependencies=['vision'])]
        r=s.run(tasks); self.assertEqual(r['vision']['status'],'NOT_TESTED'); self.assertEqual(r['approval']['status'],'BLOCKED'); self.assertEqual(self.calls,0); s.memory.close()
    def test_crash_reservation_and_append_only_chain(self):
        mem=m.Memory(self.state)
        self.assertTrue(mem.reserve('key')); mem.close()
        mem=m.Memory(self.state); self.assertTrue(mem.reserve('key')); self.assertFalse(mem.reserve('key'))
        with self.assertRaises(sqlite3.IntegrityError): mem.db.execute('DELETE FROM events')
        mem.verify(); mem.close()
    def test_tampered_memory_hash_chain_rejected(self):
        mem=m.Memory(self.state); mem.append({'event':'test'}); mem.close()
        db=sqlite3.connect(self.state); db.execute('DROP TRIGGER events_no_update'); db.execute("UPDATE events SET sha='tampered'"); db.commit(); db.close()
        with self.assertRaisesRegex(ValueError, 'integrity_failure'):
            m.Memory(self.state)
    def test_missing_tool_blocked_and_timeout_failure(self):
        s=self.sup(); s.tool=lambda name:(None,'')
        self.assertEqual(s.run([self.task()])['approval']['reason'],'godot_missing'); s.memory.close()
        # Distinct input task identity permits the independent timeout case.
        def timeout(argv,cwd,timeout):
            if 'rev-parse' in argv: return self.process(argv,cwd,timeout)
            raise subprocess.TimeoutExpired(argv,timeout)
        s=self.sup(timeout); t=dict(self.task(),id='timeout'); self.assertEqual(s.run([t])['timeout']['reason'],'executor_timeout'); s.memory.close()
    def test_inventory_cannot_claim_generative_role(self):
        with self.assertRaisesRegex(ValueError, 'executor_not_authorized_for_role'):
            m.validate_tasks([dict(id='redraw',agent='redraw',executor='inventory')],{'redraw'})
        with self.assertRaisesRegex(ValueError, 'test_does_not_validate_role'):
            m.validate_tasks([dict(id='vision',agent='approval',executor='godot',test='parse')],{'approval'})
    def test_tool_bytes_change_cache_identity(self):
        s=self.sup(); first=s.key(self.task()); s.tool=lambda name:('/synthetic/'+name,'newtoolhash')
        self.assertNotEqual(first,s.key(self.task())); s.memory.close()

if __name__ == '__main__': unittest.main()
