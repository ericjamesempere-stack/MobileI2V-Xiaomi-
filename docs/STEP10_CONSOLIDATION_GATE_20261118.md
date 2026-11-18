# KARMA ONE — Step 10 safe consolidation gate (2026-11-18)

## Immutable starting point
Base branch: karma/step09g-review-assertion-fix-20261118
Base commit: 8b3a795ec900861c8878dfbdf3b7185efcf100b9
CI evidence: https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44257383744

## Inputs to inspect and integrate selectively
- Work gallery: karma/work-gallery-agent-generation-20261118 @ 92e412176a16359514ec92cee1773373ecc34c5d
- Automatic engine fallback: karma/v61-e01-auto-engine-fallback-20261118 @ 6b0892221e9fb9c67c72b8b32ca53ffbedc96a79
- Visual-quality gate: karma/step12-visual-quality-gate-20261118 @ 25248a583cc70d9162eb12b075b4134e50e37b13
- Re-fetch remote refs before applying any changes; new successors may exist.

## Hard constraints
1. Do not reset, force-push, replace or discard the 9G validated history.
2. Branches above diverge: do not merge automatically. Review each changed file and reconcile conflicting contracts, preserving newer functionality and 9G fixes.
3. Preserve existing gallery picker, image analysis, local/remote fallback, review gates, storyboard continuity and MP4 export. Never claim hardware validation from CI alone.
4. Keep docs/KARMA_ONE_LOCKED_STEPS.md truthful. Lock only with test evidence, full SHA and links.
5. Run targeted tests, Godot regression suite and Android checks before any APK build.
6. User has authorized one build of the consolidated ARM64 version *only after* successful integration and checks. Never build an older branch, never re-run a build already in progress, and do not trigger duplicates.
7. If any check fails, stop before APK compilation and report exact failure and corrective action.
8. For a successful build, record workflow run URL, full SHA, artifact ID and expiry, SHA256 of APK if obtained, and what remains untested on Xiaomi 14T Pro.

## Step 10 execution checklist
- [ ] Refresh branches and commit ancestry.
- [ ] Review Work gallery changes against 9G.
- [ ] Review V61 fallback changes against 9G and Work.
- [ ] Reconcile agent orchestration, picker and storyboard integrations.
- [ ] Run relevant tests and regression gates.
- [ ] Update lock register with exact proof.
- [ ] Commit integrated code and inspect final SHA.
- [ ] Check existing workflow runs for that SHA before initiating one permitted build.
- [ ] Build only the final consolidated ARM64 APK after gates pass.
- [ ] Verify artifact and report device-testing limits.

This file is a plan and safety gate, NOT evidence that integration or APK build has been completed.
