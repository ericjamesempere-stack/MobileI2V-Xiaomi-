#!/usr/bin/env python3
"""Read-only CI evidence audit. No personal media, no model inference, no code changes."""
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone

REPO = os.environ.get("GITHUB_REPOSITORY", "ericjamesempere-stack/MobileI2V-Xiaomi-")
BRANCH = os.environ.get("KARMA_TARGET_BRANCH", "karma/storyboard-story-sequence-20261113")
WORKFLOWS = [
    "Validate KARMA ONE Godot scripts",
    "Verify Visual Backend API",
    "Verify 2D Storyboard Godot",
    "Build Android APK MobileI2V V50",
]

def get(path):
    token = os.environ.get("GITHUB_TOKEN", "")
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "karma-autopilot-audit"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request("https://api.github.com/repos/" + REPO + "/" + path, headers=headers)
    with urllib.request.urlopen(req, timeout=25) as response:
        return json.load(response)

def main():
    from urllib.parse import quote
    sha = get("branches/" + quote(BRANCH, safe=""))["commit"]["sha"]
    runs = get("actions/runs?branch=" + quote(BRANCH, safe="") + "&per_page=100")["workflow_runs"]
    checks = []
    for name in WORKFLOWS:
        candidates = [r for r in runs if r.get("name") == name and r.get("head_sha") == sha]
        candidates.sort(key=lambda r: r.get("created_at", ""), reverse=True)
        r = candidates[0] if candidates else None
        checks.append({"workflow": name, "status": r.get("status") if r else "missing",
                       "conclusion": r.get("conclusion") if r else None,
                       "url": r.get("html_url") if r else None,
                       "run_id": r.get("id") if r else None})
    report = {"checked_at": datetime.now(timezone.utc).isoformat(), "repository": REPO,
              "branch": BRANCH, "head_sha": sha, "checks": checks,
              "all_success": all(c["conclusion"] == "success" for c in checks),
              "limitations": ["No artifact content downloaded or decoded",
                              "No physical Android gallery test",
                              "No real generative image inference validated",
                              "No MediaPipe or free-motion generation validated"]}
    os.makedirs("autopilot/reports", exist_ok=True)
    with open("autopilot/reports/latest.json", "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["all_success"] else 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("Audit blocked:", str(exc), file=sys.stderr)
        sys.exit(2)
