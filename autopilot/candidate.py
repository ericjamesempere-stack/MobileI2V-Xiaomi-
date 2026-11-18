"""Validate an operator-selected MobileI2V commit in a disposable Git worktree."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

from autopilot.supervisor import ERRORS, ROOT, Memory, Supervisor, digest

# The first project's authorized application surfaces. The candidate cannot
# change the orchestrator, review gates, test fixtures, workflows or permissions.
MOBILEI2V_PATHS = frozenset({
    'scripts/storyboard.gd',
    'scripts/android_image_reader.gd',
    'scripts/hf_studio_generator.gd',
    'scripts/local_studio_generator.gd',
    'native/mp4exporter/src/main/java/com/mobilei2v/encoder/ReferenceImagePickerActivity.java',
    'native/mp4exporter/src/main/java/com/mobilei2v/encoder/ReferenceImageImporter.java',
})


def git(root, *args, check=True):
    return subprocess.run(['git', *args], cwd=root, check=check, capture_output=True,
                          text=True, timeout=30)


def review_candidate(candidate, state, report_dir, godot=None, budget_seconds=1800):
    # The checked-out supervisor and its committed test manifest are the trust root.
    baseline = git(ROOT, 'rev-parse', 'HEAD').stdout.strip()
    if git(ROOT, 'status', '--porcelain', '--untracked-files=no').stdout:
        raise ValueError('reviewer_checkout_dirty')
    if not re.fullmatch(r'[a-f0-9]{40}', candidate) or candidate == baseline:
        raise ValueError('distinct_full_candidate_sha_required')
    if git(ROOT, 'merge-base', '--is-ancestor', baseline, candidate, check=False).returncode:
        raise ValueError('candidate_must_descend_from_current_head')
    if ROOT in report_dir.resolve().parents or ROOT in state.resolve().parents:
        raise ValueError('candidate_state_and_reports_must_be_outside_checkout')

    report_dir.mkdir(parents=True, exist_ok=True)
    manifest = Path(__file__).with_name('tasks.json').read_bytes()
    receipt = {'baseline_sha': baseline, 'candidate_sha': candidate,
               'manifest_sha256': digest(manifest), 'may_integrate': False,
               'runner': 'autopilot_fixed_mobilei2v_checks',
               'physical_device_test': False, 'human_review_required': True}
    changed = git(ROOT, 'diff', '--no-renames', '--name-status', '-z', baseline, candidate).stdout.split('\0')[:-1]
    paths = dict(zip(changed[1::2], changed[::2]))
    # Restrict tracked, in-place regular-file changes. No modes, aliases,
    # renames, symlinks or deletions enter a runnable candidate.
    modes = git(ROOT, 'diff', '--raw', '--no-renames', baseline, candidate).stdout.splitlines()
    regular = all(line.startswith(':100644 100644 ') for line in modes)
    allowed = bool(paths) and all(kind == 'M' and path in MOBILEI2V_PATHS for path, kind in paths.items())
    if not allowed or not regular:
        receipt.update(decision='REJECT', reason='candidate_changes_outside_project_contract')
    elif git(ROOT, 'diff', '--check', baseline, candidate, check=False).returncode:
        receipt.update(decision='REJECT', reason='git_diff_check_failed')
    else:
        receipt['changed_paths'] = sorted(paths)
        with tempfile.TemporaryDirectory(prefix='karma-candidate-') as temp:
            worktree = Path(temp) / 'checkout'
            git(ROOT, 'worktree', 'add', '--detach', str(worktree), candidate)
            try:
                sup = Supervisor(root=worktree, state=state, report_dir=report_dir, godot=godot)
                try:
                    executable, _ = sup.tool('godot')
                    if not executable:
                        receipt.update(decision='BLOCKED', reason='godot_missing')
                    else:
                        validate(sup, executable, temp, manifest, receipt, budget_seconds)
                finally:
                    sup.memory.close()
            finally:
                git(ROOT, 'worktree', 'remove', '--force', str(worktree))
        receipt['temporary_worktree_removed'] = True
    # Record the decision even if preflight rejects it. The candidate object is
    # retained in Git, while the operator's branch remains at its checkpoint.
    receipt['baseline_preserved'] = git(ROOT, 'rev-parse', 'HEAD').stdout.strip() == baseline
    if not receipt['baseline_preserved']:
        receipt.update(decision='BLOCKED', reason='baseline_changed_during_review')
    proof = Supervisor._write_evidence_path(report_dir, 'candidate-review', receipt)
    with_memory = Memory(state)
    try:
        with_memory.append({'event': 'candidate_review', 'baseline_sha': baseline,
                            'candidate_sha': candidate, 'decision': receipt['decision'],
                            'reason': receipt['reason'], 'evidence_sha256': proof['sha256']})
    finally:
        with_memory.close()
    return receipt, proof


def validate(sup, executable, temp, manifest, receipt, budget_seconds):
    # Separate test projects avoid inheriting real user data or cached drawings.
    xdg = Path(temp) / 'test-data'
    xdg.mkdir()
    process = sup.process
    env = {key: os.environ[key] for key in ('PATH', 'LANG', 'LC_ALL', 'SYSTEMROOT') if key in os.environ}
    env.update(XDG_DATA_HOME=str(xdg), XDG_CONFIG_HOME=str(xdg), XDG_CACHE_HOME=str(xdg))
    def isolated_process(argv, cwd, timeout):
        return subprocess.run(argv, cwd=cwd, timeout=timeout, check=False,
                              capture_output=True, text=True, env=env)
    deadline = time.monotonic() + budget_seconds
    sup.process = isolated_process
    try:
        try:
            imported = sup.process([executable, '--headless', '--editor', '--import', '--quit'],
                                   sup.root, timeout=min(90, budget_seconds))
        except subprocess.TimeoutExpired:
            receipt.update(decision='BLOCKED', reason='godot_import_timeout')
            return
        import_log = imported.stdout + imported.stderr
        receipt['import_output_sha256'] = digest(import_log)
        if imported.returncode != 0 or ERRORS.search(import_log):
            receipt.update(decision='REJECT', reason='godot_project_import_failed')
            return
        # Reserve a short window for the independent agent to record the decision.
        results = sup.run(json.loads(manifest)['tasks'], budget_seconds=max(0, deadline - time.monotonic() - 3))
        receipt['checks'] = {name: {'status': result['status'], 'reason': result['reason'],
                                   'evidence_sha256': [a['sha256'] for a in result['artifacts']]}
                             for name, result in results.items()}
        checks_file = Path(temp) / 'check-receipts.json'
        checks_file.write_text(json.dumps(receipt['checks']), encoding='utf-8')
        time_left = deadline - time.monotonic()
        if time_left <= 0:
            receipt.update(decision='BLOCKED', reason='review_budget_exhausted')
            return
        try:
            review = sup.process([executable, '--headless', '--script',
                                  'res://autopilot/review_checks.gd', '--', str(checks_file)],
                                 sup.root, timeout=min(10, time_left))
        except subprocess.TimeoutExpired:
            receipt.update(decision='BLOCKED', reason='code_test_agent_timeout')
            return
        output = review.stdout + review.stderr
        prefix = 'KARMA_CANDIDATE_REVIEW '
        decisions = [line[len(prefix):] for line in review.stdout.splitlines() if line.startswith(prefix)]
        if review.returncode or ERRORS.search(output) or len(decisions) != 1:
            receipt.update(decision='BLOCKED', reason='code_test_agent_failed')
            return
        decision = json.loads(decisions[0])
        mapping = {'BLOCKED', 'REJECT', 'REVIEW_REQUIRED'}
        if not isinstance(decision, dict) or decision.get('decision') not in mapping:
            receipt.update(decision='BLOCKED', reason='invalid_code_test_agent_decision')
            return
        receipt.update(decision=decision['decision'], reason=decision['reason'],
                       review_agent='karma_code_test_agent.gd', review_output_sha256=digest(output))
    finally:
        sup.process = process


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', help='Full SHA of a trusted local candidate commit')
    parser.add_argument('--state', required=True, type=Path)
    parser.add_argument('--report-dir', required=True, type=Path)
    parser.add_argument('--godot')
    parser.add_argument('--budget-seconds', type=int, default=1800, choices=range(1, 1801), metavar='1..1800')
    args = parser.parse_args()
    try:
        receipt, proof = review_candidate(args.candidate, args.state, args.report_dir, args.godot, args.budget_seconds)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        reason = str(exc) if isinstance(exc, ValueError) else type(exc).__name__
        print(json.dumps({'decision': 'BLOCKED', 'reason': reason}))
        return 2
    print(json.dumps({'decision': receipt['decision'], 'reason': receipt['reason'], 'receipt': proof}, indent=2))
    return {'REVIEW_REQUIRED': 0, 'REJECT': 1, 'BLOCKED': 2}[receipt['decision']]


if __name__ == '__main__':
    raise SystemExit(main())
