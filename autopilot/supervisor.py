#!/usr/bin/env python3
"""KarmaWan V2: bounded deterministic executors; no autonomous LLM or code mutation."""
from __future__ import annotations
from contextlib import contextmanager
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = Path(__file__).with_name('agent_registry.json')
# Inputs select a named test, never an arbitrary script or shell command.
GODOT_TESTS = {
    'parse': ('tests/validate_karma_one.gd', 'KARMA ONE: all selected scripts parsed successfully'),
    'approval': ('tests/test_reference_review_pipeline.gd', 'REFERENCE_IMPORT_SUBJECT_PROMPT_AND_REVIEW_GATE_OK'),
    'universal_contract': ('tests/test_universal_board_contract.gd', 'UNIVERSAL_BOARD_CONTRACT_OK'),
    'intermediate': ('tests/test_karma_intermediate_agent.gd', 'V54_INTERMEDIATE_AGENT_CONTRACT_OK'),
    'integration': ('tests/test_universal_android_integration.gd', 'UNIVERSAL_ANDROID_INTEGRATION_OK'),
    'agent_supervisor': ('tests/test_karma_agent_supervisor.gd', 'PASS karma_agent_supervisor'),
    'agent_control': ('tests/test_karma_control_lab.gd', 'PASS karma_control_lab'),
    'agent_learning': ('tests/test_karma_agent_learning_lab.gd', 'PASS karma_agent_learning_lab'),
    'agent_experience': ('tests/test_karma_agent_experience.gd', 'PASS karma_agent_experience'),
    'code_test': ('tests/test_karma_code_test_agent.gd', 'PASS karma_code_test_agent'),
    'technical_memory': ('tests/test_karma_technical_memory.gd', 'AUTOPILOT_TECHNICAL_MEMORY_OK'),
    'photo_recovery': ('tests/test_v58_photo_recovery.gd', 'V58_PHOTO_RECOVERY_OK'),
    'assisted_receive': ('tests/test_v60_simplified_receive.gd', 'V60_SIMPLIFIED_RECEIVE_OK'),
}
ERRORS = re.compile(r'SCRIPT ERROR|Parse Error|Assertion failed|Failed to load script|INVALID SCRIPT|INVALID MAIN SCENE|\bERROR:|\bFATAL:', re.I)
ID = re.compile(r'^[a-z][a-z0-9_]{0,63}$')
STATUS = {'PASS', 'FAIL', 'BLOCKED', 'NOT_TESTED'}
EXECUTOR_AGENTS = {
    'inventory': {'inventory'}, 'godot': {'integration','approval','motion','storyboard','qa','security'},
    'video': {'video'}, 'apk': {'android'}, 'github_audit': {'inventory','qa'},
}
TEST_AGENTS = {
    'parse': {'integration','qa'}, 'approval': {'approval','qa','security'},
    'universal_contract': {'motion','integration','qa'},
    'intermediate': {'storyboard','motion','qa'}, 'integration': {'integration','qa'},
    'agent_supervisor': {'integration'}, 'agent_control': {'security'}, 'agent_learning': {'qa'},
    'agent_experience': {'qa'}, 'code_test': {'qa'}, 'technical_memory': {'qa'},
    'photo_recovery': {'integration'}, 'assisted_receive': {'qa'},
}

def canonical(value):
    return json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(',', ':'))

def digest(value):
    return hashlib.sha256(value if isinstance(value, bytes) else str(value).encode()).hexdigest()

def file_sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def run_process(argv, cwd, timeout=90):
    """argv only. Output is inspected in memory and never written to technical memory."""
    return subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=timeout,
                          check=False, shell=False)

class Memory:
    """Append-only hash-chained events, with separate mutable success cache."""
    def __init__(self, path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(self.path)
        self.db.execute('PRAGMA busy_timeout=30000')
        self.db.executescript('''
          CREATE TABLE IF NOT EXISTS events (n INTEGER PRIMARY KEY, payload TEXT NOT NULL,
            previous TEXT NOT NULL, sha TEXT NOT NULL);
          CREATE TRIGGER IF NOT EXISTS events_no_update BEFORE UPDATE ON events
            BEGIN SELECT RAISE(ABORT, 'append-only'); END;
          CREATE TRIGGER IF NOT EXISTS events_no_delete BEFORE DELETE ON events
            BEGIN SELECT RAISE(ABORT, 'append-only'); END;
          CREATE TABLE IF NOT EXISTS cache (key TEXT PRIMARY KEY, result TEXT NOT NULL);
        ''')
        try:
            self.verify()
            self.migrate()
        except BaseException:
            self.db.close()
            raise

    def migrate(self):
        with self.write_transaction():
            version = self.db.execute('PRAGMA user_version').fetchone()[0]
            if version == 0:
                self.db.execute('''CREATE INDEX IF NOT EXISTS events_attempt_key
                    ON events(json_extract(payload, '$.key'))
                    WHERE json_extract(payload, '$.event') = 'attempt' ''')
                self.db.execute('PRAGMA user_version = 1')
            elif version != 1:
                raise ValueError('technical_memory_schema_unsupported')

    def verify(self):
        previous = ''
        for _, payload, prev, sha in self.db.execute('SELECT * FROM events ORDER BY n'):
            if prev != previous or sha != digest(previous + payload):
                raise ValueError('technical_memory_integrity_failure')
            previous = sha

    def _append(self, value):
        last = self.db.execute('SELECT sha FROM events ORDER BY n DESC LIMIT 1').fetchone()
        previous = last[0] if last else ''
        payload = canonical(dict(value, at=int(time.time())))
        self.db.execute('INSERT INTO events(payload,previous,sha) VALUES(?,?,?)',
                        (payload, previous, digest(previous + payload)))

    @contextmanager
    def write_transaction(self):
        self.db.execute('BEGIN IMMEDIATE')
        try:
            yield
            self.db.commit()
        except BaseException:
            self.db.rollback()
            raise

    def append(self, value):
        with self.write_transaction():
            self._append(value)

    def reserve(self, key, maximum=2):
        # Reserve before execution; a crash cannot create unlimited retries.
        with self.write_transaction():
            used = self.db.execute('''SELECT count(*) FROM events
                WHERE json_extract(payload, '$.event') = 'attempt'
                  AND json_extract(payload, '$.key') = ?''', (key,)).fetchone()[0]
            if used >= min(maximum, 2):
                return False
            self._append({'event': 'attempt', 'key': key, 'attempt': used + 1})
            return True

    def cached(self, key):
        row = self.db.execute('SELECT result FROM cache WHERE key=?', (key,)).fetchone()
        return json.loads(row[0]) if row else None

    def finish(self, event, result=None):
        # Publish the success checkpoint and its journal entry together.
        with self.write_transaction():
            self._append(event)
            if result is not None:
                self.db.execute('INSERT OR REPLACE INTO cache VALUES(?,?)',
                                (event['key'], canonical(result)))

    def close(self):
        self.db.close()


def validate_tasks(tasks, agents):
    by_id = {}
    for t in tasks:
        if not isinstance(t, dict) or not ID.fullmatch(str(t.get('id', ''))):
            raise ValueError('invalid_task_id')
        deps = t.get('dependencies', [])
        if not isinstance(deps, list) or any(not isinstance(d, str) for d in deps):
            raise ValueError('invalid_dependencies')
        if len(set(deps)) != len(deps):
            raise ValueError('duplicate_dependency')
        if t['id'] in by_id or t.get('agent') not in agents:
            raise ValueError('duplicate_task_or_unknown_agent')
        # No configurable command, script, URL or executable is accepted.
        if set(t) - {'id','agent','objective','inputs','dependencies','acceptance_criteria','max_attempts','privacy_class','executor','test','artifact','expected','cache'}:
            raise ValueError('unsupported_task_field')
        if t.get('privacy_class', 'synthetic') != 'synthetic':
            raise ValueError('only_synthetic_technical_tasks_allowed')
        if not isinstance(t.get('max_attempts', 2), int) or not 1 <= t.get('max_attempts', 2) <= 2:
            raise ValueError('invalid_retry_budget')
        executor = t.get('executor', 'unconnected')
        if not isinstance(executor, str) or executor not in {*EXECUTOR_AGENTS, 'unconnected'}:
            raise ValueError('unsupported_executor')
        if executor in EXECUTOR_AGENTS and t.get('agent') not in EXECUTOR_AGENTS[executor]:
            raise ValueError('executor_not_authorized_for_role')
        if executor == 'godot':
            if t.get('test') not in GODOT_TESTS:
                raise ValueError('godot_test_not_allowlisted')
            if t.get('agent') not in TEST_AGENTS[t['test']]:
                raise ValueError('test_does_not_validate_role')
        by_id[t['id']] = t
    ordered, active, done = [], set(), set()
    def visit(tid):
        if tid not in by_id:
            raise ValueError('unknown_dependency')
        if tid in active:
            raise ValueError('dependency_cycle')
        if tid in done:
            return
        active.add(tid)
        for dep in by_id[tid].get('dependencies', []):
            visit(dep)
        active.remove(tid)
        done.add(tid)
        ordered.append(by_id[tid])
    for tid in by_id:
        visit(tid)
    return ordered


def source_fingerprint(root):
    """Hash actual source and configuration, including edits before commit."""
    roots = ['scripts', 'tests', 'native', 'addons', 'autopilot', 'scenes', 'assets', '.github/workflows']
    paths = [root / 'project.godot', root / 'export_presets.cfg']
    for folder in roots:
        p = root / folder
        if p.is_dir():
            paths.extend(x for x in p.rglob('*') if x.is_file() and
                         x.suffix.lower() in {'.gd','.py','.java','.gradle','.cfg','.json','.tscn','.yml','.xml','.png','.jpg','.jpeg','.webp','.svg','.tres','.shader','.gdshader'} and
                         '__pycache__' not in x.parts and 'reports' not in x.parts and 'state' not in x.parts)
    return digest(canonical([(str(p.relative_to(root)), file_sha(p)) for p in sorted(set(paths)) if p.is_file()]))

class Supervisor:
    def __init__(self, root=ROOT, state=None, report_dir=None, godot=None, artifacts=None, process=run_process):
        self.root = Path(root).resolve()
        self.report_dir = Path(report_dir or self.root / 'autopilot/reports').resolve()
        self.report_dir.mkdir(parents=True, exist_ok=True)
        self.memory = Memory(state or self.root / 'autopilot/state/technical.sqlite3')
        self.godot = godot or os.environ.get('GODOT_BIN', 'godot')
        self.artifacts = artifacts or {}
        self.process = process
        self.deadline = None
        self.source_sha = source_fingerprint(self.root)
        self.commit = self._git(['rev-parse', 'HEAD']).strip()
        if not re.fullmatch('[0-9a-f]{40,64}', self.commit):
            self.commit = ''
        self._tool_cache = {}

    def _invoke(self, argv, cwd, timeout):
        if self.deadline is not None:
            timeout = min(timeout, self.deadline - time.monotonic())
            if timeout <= 0:
                raise subprocess.TimeoutExpired(argv, timeout)
        return self.process(argv, cwd, timeout=timeout)

    def _git(self, args):
        git = shutil.which('git')
        if not git:
            return ''
        r = self._invoke([git] + args, self.root, timeout=15)
        return r.stdout if r.returncode == 0 else ''

    def tool(self, name):
        name = self.godot if name == 'godot' else name
        if name not in self._tool_cache:
            found = shutil.which(name)
            # Resolve symlinks so changing the invoked tool invalidates its identity.
            if found:
                found = str(Path(found).resolve())
            self._tool_cache[name] = (found, file_sha(found) if found else '')
        return self._tool_cache[name]

    def result(self, status, reason, label, **extra):
        return dict(status=status, reason=reason, evidence_type=label, commit_sha=self.commit,
                    source_sha=self.source_sha, artifacts=[], evidence_urls=[], limitations=[],
                    next_action='review_evidence' if status == 'PASS' else 'resolve_reported_blocker', **extra)

    def _artifact(self, t):
        name = t.get('artifact', '')
        if name not in {'mp4', 'apk'}:
            return None
        p = self.artifacts.get(name)
        return Path(p).resolve() if p else None

    def key(self, t, dependency_keys=()):
        dependencies = {'godot':['godot'], 'video':['ffprobe','ffmpeg'], 'apk':['apksigner'], 'inventory':['git']}
        tools = [(n, self.tool(n)[1]) for n in dependencies.get(t.get('executor'), [])]
        p = self._artifact(t)
        source = file_sha(p) if p and p.is_file() else ''
        return digest(canonical({'task': t, 'source': self.source_sha, 'commit': self.commit,
                                 'artifact': source, 'tools': tools, 'dependencies': dependency_keys}))

    @staticmethod
    def _write_atomic(path, data):
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as handle:
            temp = Path(handle.name)
            try:
                handle.write(data)
                handle.flush()
                os.fsync(handle.fileno())
                os.replace(temp, path)
            finally:
                temp.unlink(missing_ok=True)

    def _write_evidence(self, tid, evidence):
        data = (json.dumps(evidence, indent=2) + '\n').encode()
        sha = digest(data)
        path = self.report_dir / (tid + '-' + sha + '.json')
        self._write_atomic(path, data)
        return {'path': str(path), 'sha256': sha}

    @staticmethod
    def _cache_valid(result):
        return result.get('status') == 'PASS' and bool(result.get('artifacts')) and all(
            Path(a['path']).is_file() and file_sha(a['path']) == a['sha256']
            for a in result.get('artifacts', []))

    def execute(self, t):
        kind = t.get('executor', 'unconnected')
        if kind == 'inventory':
            branches = self._git(['for-each-ref', '--format=%(refname:short) %(objectname)', 'refs/remotes/origin'])
            if not self.commit or not branches:
                return self.result('BLOCKED', 'git_inventory_unavailable', 'REPOSITORY_INVENTORY')
            return self.result('PASS', 'git_refs_and_source_hashed', 'REPOSITORY_INVENTORY',
                               details={'refs':branches.splitlines(), 'source_sha':self.source_sha})
        if kind == 'godot':
            exe, _ = self.tool('godot')
            if not exe:
                return self.result('BLOCKED', 'godot_missing', 'TEST_INTEGRATION')
            script, marker = GODOT_TESTS[t['test']]
            if not (self.root / script).is_file():
                return self.result('BLOCKED', 'allowlisted_test_missing', 'TEST_INTEGRATION')
            r = self._invoke([exe,'--headless','--path',str(self.root),'--script','res://' + script], self.root, timeout=120)
            output = r.stdout + r.stderr
            ok = r.returncode == 0 and marker in output and not ERRORS.search(output)
            # Keep fingerprints and fixed categories, never arbitrary exception/output text.
            return self.result('PASS' if ok else 'FAIL', 'godot_test_passed' if ok else 'godot_test_failed',
                               'TEST_INTEGRATION', details={'test':t['test'], 'exit_code':r.returncode,
                               'success_marker':marker in output, 'error_marker':bool(ERRORS.search(output)),
                               'output_sha256':digest(output), 'simulated_inference':True, 'device_test':False})
        if kind == 'video':
            p = self._artifact(t)
            probe, _ = self.tool('ffprobe')
            ffmpeg, _ = self.tool('ffmpeg')
            if not p or not p.is_file() or not probe or not ffmpeg:
                return self.result('BLOCKED', 'mp4_or_video_tools_missing', 'FICHIER_MP4_DECODE')
            r = self._invoke([probe,'-v','error','-select_streams','v:0','-count_frames',
                              '-show_entries','stream=codec_name,pix_fmt,width,height,r_frame_rate,avg_frame_rate,nb_frames,nb_read_frames,duration:format=duration',
                              '-of','json',str(p)], self.root, timeout=120)
            try:
                data = json.loads(r.stdout)
                s = data['streams'][0]
                frames = int(s['nb_read_frames'])
                seconds = float(s.get('duration', data['format']['duration']))
                ok = r.returncode == 0 and s['codec_name'] == 'h264' and int(s['width']) > 0 and int(s['height']) > 0 and frames > 0 and seconds > 0
                expected = t.get('expected', {})
                if not isinstance(expected, dict) or set(expected) - {'width','height','frames','duration','fps'}:
                    raise ValueError('invalid_expectations')
                for field, actual in [('width',int(s['width'])),('height',int(s['height'])),('frames',frames),('duration',seconds),('fps',s['r_frame_rate'])]:
                    if field in expected:
                        ok = ok and actual == expected[field]
            except (ValueError, KeyError, IndexError, TypeError):
                return self.result('FAIL', 'invalid_video_metadata', 'FICHIER_MP4_DECODE')
            decoded = self._invoke([ffmpeg,'-v','error','-xerror','-i',str(p),'-f','null','-'], self.root, timeout=120)
            ok = ok and decoded.returncode == 0
            return self.result('PASS' if ok else 'FAIL', 'h264_decoded' if ok else 'video_verification_failed',
                               'FICHIER_MP4_DECODE', details={'streams':data['streams'],'format':data.get('format',{}),
                               'full_decode':decoded.returncode == 0,'file_sha256':file_sha(p),'device_test':False})
        if kind == 'apk':
            p = self._artifact(t)
            if not p or not p.is_file():
                return self.result('BLOCKED', 'apk_missing', 'APK_PACKAGE_INSPECTION')
            try:
                with zipfile.ZipFile(p) as z:
                    names = z.namelist()
                    abis = sorted({n.split('/')[1] for n in names if n.startswith('lib/') and n.endswith('.so')})
                    ok = z.testzip() is None and abis == ['arm64-v8a'] and 'AndroidManifest.xml' in names and 'lib/arm64-v8a/libgodot_android.so' in names
                    dex = b''.join(z.read(n) for n in names if re.fullmatch(r'classes[0-9]*\.dex', n))
                    ok = ok and b'Lcom/mobilei2v/encoder/MP4Exporter;' in dex and b'Lcom/mobilei2v/encoder/ReferenceImageImporter;' in dex
            except (OSError, zipfile.BadZipFile, KeyError):
                return self.result('FAIL', 'invalid_apk_archive', 'APK_PACKAGE_INSPECTION')
            if not ok:
                return self.result('FAIL', 'apk_arm64_or_plugin_missing', 'APK_PACKAGE_INSPECTION')
            signer, _ = self.tool('apksigner')
            if not signer:
                return self.result('BLOCKED', 'apksigner_missing_signature_unverified', 'APK_PACKAGE_INSPECTION',
                                   details={'abi':abis,'archive_valid':True,'native_plugins_present':True,'file_sha256':file_sha(p)})
            signed = self._invoke([signer,'verify','--verbose','--print-certs',str(p)], self.root, timeout=60)
            certificates = re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F:]+)', signed.stdout)
            return self.result('PASS' if signed.returncode == 0 else 'FAIL', 'apk_signature_verified' if signed.returncode == 0 else 'apk_signature_failed',
                               'APK_PACKAGE_INSPECTION', details={'abi':abis,'file_sha256':file_sha(p),'certificate_sha256':certificates,'device_test':False})
        if kind == 'github_audit':
            from autopilot.audit import audit
            try:
                remaining = self.deadline - time.monotonic() if self.deadline is not None else 25
                if remaining <= 0:
                    raise subprocess.TimeoutExpired('github_audit', remaining)
                evidence = audit(commit_sha=self.commit, timeout=min(25, remaining))
            except subprocess.TimeoutExpired:
                raise
            except Exception:
                return self.result('BLOCKED', 'github_read_unavailable', 'GITHUB_ACTIONS_EVIDENCE')
            ok = evidence['all_success']
            result = self.result('PASS' if ok else 'BLOCKED', 'ci_success_on_commit' if ok else 'ci_missing_or_unsuccessful', 'GITHUB_ACTIONS_EVIDENCE', details=evidence)
            result['evidence_urls'] = [x['url'] for x in evidence['checks'] if x.get('url')]
            return result
        return self.result('NOT_TESTED', 'executor_not_connected', 'UNCONNECTED_ROLE')

    def run(self, tasks, budget_seconds=1800):
        agents = {a['id'] for a in json.loads(REGISTRY.read_text())['agents']}
        ordered = validate_tasks(tasks, agents)
        results, keys = {}, {}
        self.deadline = time.monotonic() + budget_seconds
        for t in ordered:
            tid = t['id']
            deps = t.get('dependencies', [])
            key = self.key(t, [keys[d] for d in deps])
            keys[tid] = key
            cache = self.memory.cached(key)
            promote = False
            if any(results[d]['status'] != 'PASS' for d in deps):
                result = self.result('BLOCKED', 'dependency_not_passed', 'DEPENDENCY_GATE')
            elif t.get('cache', True) and t.get('executor') != 'github_audit' and cache and self._cache_valid(cache):
                result = dict(cache, cached=True)
            elif time.monotonic() >= self.deadline:
                result = self.result('BLOCKED', 'mission_time_budget_exhausted', 'EXECUTION_BUDGET')
            elif not self.memory.reserve(key, t.get('max_attempts', 2)):
                result = self.result('BLOCKED', 'attempt_budget_exhausted', 'CORRECTION_BUDGET')
            else:
                # All connected executors are read-only or use local fixture output.
                started = time.monotonic()
                try:
                    result = self.execute(t)
                except subprocess.TimeoutExpired:
                    if time.monotonic() >= self.deadline:
                        result = self.result('BLOCKED', 'mission_time_budget_exhausted', 'EXECUTION_BUDGET')
                    else:
                        result = self.result('FAIL', 'executor_timeout', 'EXECUTOR_FAILURE')
                except Exception:
                    result = self.result('BLOCKED', 'executor_exception_no_private_output_saved', 'EXECUTOR_FAILURE')
                result['elapsed_ms'] = round((time.monotonic() - started) * 1000)
                result['agent'] = t['agent']
                result['dependencies'] = deps
                result['artifacts'] = [self._write_evidence(tid, result)]
                promote = result['status'] == 'PASS' and t.get('cache', True) and t.get('executor') != 'github_audit'
            result['agent'] = t['agent']
            result['dependencies'] = deps
            results[tid] = result
            self.memory.finish({'event':'result','key':key,'task_id':tid,'status':result['status'],
                                'reason':result['reason'],'source_sha':self.source_sha,'commit_sha':self.commit,
                                'signature':digest(result['reason']),'cached':result.get('cached',False),
                                'evidence_sha256':[a['sha256'] for a in result['artifacts']]},
                               result if promote else None)
        self.deadline = None
        report = {'version':'AUTOPILOT_V3','tasks':results,
                  'limitations':['Deterministic executors',
                                 'Fixture tests do not prove real image inference or Xiaomi operation',
                                 'Candidate integration requires a separate human decision']}
        self._write_atomic(self.report_dir / 'latest.json', (json.dumps(report, indent=2) + '\n').encode())
        return results


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--tasks', type=Path, default=Path(__file__).with_name('tasks.json'))
    ap.add_argument('--state', type=Path)
    ap.add_argument('--report-dir', type=Path)
    ap.add_argument('--godot')
    ap.add_argument('--budget-seconds', type=int, default=1800, choices=range(1, 1801), metavar='1..1800')
    ap.add_argument('--mp4', type=Path)
    ap.add_argument('--apk', type=Path)
    args = ap.parse_args()
    sup = Supervisor(state=args.state,report_dir=args.report_dir,godot=args.godot,
                     artifacts={k:v for k,v in {'mp4':args.mp4,'apk':args.apk}.items() if v})
    try:
        result = sup.run(json.loads(args.tasks.read_text())['tasks'], budget_seconds=args.budget_seconds)
        print(json.dumps({tid:{'status':r['status'],'reason':r['reason'],'cached':r.get('cached',False)} for tid,r in result.items()},indent=2))
        return 0 if all(r['status'] == 'PASS' for r in result.values()) else 1
    finally:
        sup.memory.close()

if __name__ == '__main__':
    # Permit both module and direct CLI use, without relying on caller PYTHONPATH.
    sys.path.insert(0, str(ROOT))
    raise SystemExit(main())
