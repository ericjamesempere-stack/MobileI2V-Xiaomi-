#!/usr/bin/env python3
"""Read-only CI audit, inherited from V1; no dispatch, retry, merge or upload."""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.request
from urllib.parse import quote
from datetime import datetime, timezone

REPO = os.environ.get('GITHUB_REPOSITORY', 'ericjamesempere-stack/MobileI2V-Xiaomi-')
BRANCH = os.environ.get('KARMA_TARGET_BRANCH', 'karma/autopilot-v2-20261117')
# This version's Android workflow includes parser, native, approval and MP4 checks.
# Historical V53/V54 evidence is preserved separately in validation/autopilot-v2.
WORKFLOWS = ['Build Android APK KARMA ONE AUTOPILOT V2']

def get(path):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', REPO):
        raise ValueError('invalid_repository')
    headers = {'Accept':'application/vnd.github+json', 'User-Agent':'karma-autopilot-audit'}
    token = os.environ.get('GITHUB_TOKEN','')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request('https://api.github.com/repos/' + REPO + '/' + path, headers=headers)
    with urllib.request.urlopen(request, timeout=25) as response:
        return json.load(response)

def audit(commit_sha=None):
    sha = commit_sha or get('branches/' + quote(BRANCH,safe=''))['commit']['sha']
    if not re.fullmatch(r'[0-9a-f]{40,64}',sha):
        raise ValueError('invalid_commit')
    runs = get('actions/runs?head_sha=' + sha + '&per_page=100')['workflow_runs']
    checks = []
    for name in WORKFLOWS:
        candidates = [r for r in runs if r.get('name') == name and r.get('head_sha') == sha]
        candidates.sort(key=lambda r:(r.get('created_at',''),r.get('run_attempt',1)),reverse=True)
        r = candidates[0] if candidates else {}
        checks.append({'workflow':name,'status':r.get('status','missing'),'conclusion':r.get('conclusion'),
                       'url':r.get('html_url'),'run_id':r.get('id'),'head_sha':r.get('head_sha')})
    return {'checked_at':datetime.now(timezone.utc).isoformat(),'repository':REPO,'branch':BRANCH,
            'head_sha':sha,'checks':checks,'all_success':all(c['conclusion']=='success' for c in checks),
            'limitations':['Artifacts not downloaded or decoded by this audit',
                           'CI success does not prove physical Android or real inference']}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--commit')
    p.add_argument('--output',type=Path,default=Path('autopilot/reports/github-audit.json'))
    args = p.parse_args()
    try:
        result = audit(args.commit)
    except Exception:
        print('Audit BLOCKED: GitHub evidence unavailable; private exception details omitted',file=sys.stderr)
        return 2
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return 0 if result['all_success'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
