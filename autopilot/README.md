# KARMA ONE AUTOPILOT V2

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
Unknown executors report NOT_TESTED. No role gains PASS from its declaration.

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
