# KARMA ONE AUTOPILOT

KarmaWan now executes a dependency graph through real, fixed tools: Git inventory,
allowlisted Godot tests, FFprobe/full FFmpeg decode, APK ABI/plugin/signature
inspection, and read-only GitHub Actions evidence. V53/V54 runtime modules remain
in place. These are deterministic specialized executors, **not trained LLM
agents**, and the supervisor never edits application code or approves drawings.

```bash
python3 autopilot/supervisor.py --godot /path/to/godot
python3 autopilot/supervisor.py --tasks autopilot/artifact_tasks.json --mp4 /path/to/synthetic-demo.mp4 --apk /path/to/build.apk
python3 autopilot/audit.py --commit FULL_COMMIT_SHA
python3 -m unittest discover -s tests -p test_autopilot.py -v
python3 -m autopilot.candidate FULL_CANDIDATE_SHA --state /tmp/karma-technical.sqlite3 --report-dir /tmp/karma-review
```

The existing build workflow remains responsible for compiling Android and its
MediaCodec plugin. The APK executor inspects a produced build and requires
`apksigner` on PATH; it reports BLOCKED if signature verification is unavailable.
The video executor verifies a supplied file; it does not certify model fidelity
or Xiaomi playback. The Godot integration test uses synthetic drawings and a
substituted MediaCodec encoder. A PASS is scoped to the named evidence type.

`agent_registry.json` retains all 13 V1 roles and forbidden actions.
`mission_tasks_v1.json` preserves the original mission dependency graph as
unexecuted criteria. `tasks.json` contains connected offline checks, separately
from unconnected real inference, MediaPipe and physical-device mission work.
Roles explicitly marked unconnected report NOT_TESTED. Unknown executors are rejected. No role gains PASS from its declaration.

Technical memory defaults to `autopilot/state/technical.sqlite3`; use `--state`
to select durable private storage. Results are in `autopilot/reports/`; use
`--report-dir` when needed. State and reports are excluded from git. Memory stores
hashes, fixed status/error categories and source/commit identities, never source
images, prompts, tokens or raw process output. Structured video/APK evidence
contains only technical metadata. Use **synthetic/public test media only**.

Each execution reserves its attempt before launch. The same task/source/tool/input
identity has at most two attempts, surviving restarts and crashes. A changed fix
changes the source identity; failure events remain in the append-only hash chain.
There is no self-modification or hidden budget reset. Success is reused only
when source, commit, task, tools and input hashes match and the on-disk evidence
still hashes correctly. GitHub CI evidence is always refreshed, never cached.
Dependencies fail closed. Runtime errors in Godot fail even when it returns zero.

Executors use argument arrays without a shell. Tasks cannot select commands,
executables, URLs or arbitrary test files. Timeouts bound all external tools.
There is no push, merge, publish, paid service, live model retry or automatic
correction executor. Proposed fixes still require a versioned branch and tests;
physical Xiaomi tests and real universal generation remain separate mission gates.


## Supervised MobileI2V patch review

Run the candidate command from the clean, trusted baseline checkout. Pass the full
SHA of a trusted descendant commit. The current MobileI2V policy admits changes
to existing app files listed in `candidate.py`. Tests, review policy and CI are
outside that list. The Git checkpoint and literal manifest are bound to the
receipt. The disposable worktree runs with temporary Godot data/config and a short
environment allowlist. This runs local application code from the trusted commit.

The V60 code-test agent consumes the receipts in a separate Godot process, after
the V60 guard authorizes evaluation. REJECT covers an observed gate failure.
BLOCKED covers missing proof, infrastructure or remaining budget. REVIEW_REQUIRED
means the configured local gates passed. The human controls integration, and
device, measurement and live inference evidence need their own checks.

Desktop Autopilot allows one DAG per SQLite state. Each completed success is
bound to its append-only checkpoint and checksummed evidence. Use the same state
and report directory to resume. The cap is two attempts per task fingerprint.
The mission execution budget defaults to 30 minutes and can be reduced with
`--budget-seconds`. A previously verified matching task can be read from cache.
