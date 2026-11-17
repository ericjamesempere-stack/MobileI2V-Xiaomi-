# KARMA ONE AUTOPILOT — supervisor foundation

This branch starts from V54 and preserves all existing project files. Do not merge automatically.

## Mission
Complete the existing Android application: gallery → visual analysis and prompt → universal faithful redraw → storyboard → Keep/Reject/Redo → mandatory approval → animation → H.264 MP4.

## Agents (roles, not claims of already-running AI models)
- **Coordinator:** prioritize tasks and track dependencies.
- **Repository auditor:** inspect changes and CI results.
- **Vision/fidelity auditor:** verify subject identity and reference consistency (e.g. banana remains a banana).
- **Storyboard auditor:** validate successive distinct images, not just zoom/warp.
- **Android auditor:** gallery picker, persisted private image, ARM64 APK.
- **Video auditor:** decode actual MP4, report codec/duration/FPS/frame count.
- **Regression guardian:** protect V53/V54 functions and required approval.
- **Memory:** append evidence and lessons, avoid repeating already successful checks.

## Safety rules
1. Never upload private images or personal media to GitHub.
2. Never claim simulated, 2D transform, ONNX interface, or CI contract tests prove real generative inference.
3. No auto-merge, force-push, branch deletion, or destructive changes.
4. Changes happen on dedicated branches with tests and review.
5. Stop after repeated identical failures; record a blocking issue.
6. No promise of unlimited free GPU or autonomous model self-training.

## Current baseline
V53 successful workflows on commit 769614a5913ba9e83e1a040c0e21422f3d51125d:
- Validate Godot: https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43805059374
- Visual Backend API: https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43805059351
- 2D Storyboard: https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43805059403
- ARM64 APK: https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43805059322

V54 previously reported successes on 1276cebd, subject to revalidation against the exact current branch head.
Claude's recent gallery picker, ETC2/ASTC fix, storyboard module and H.264 encoder are **unverified until their files are committed and inspected**.

## What is and isn't implemented
This initial supervisor provides an executable, read-only GitHub Actions audit and persistent run reports as artifacts. It does NOT yet automatically edit code, install an APK on a physical Xiaomi, train AI models, or generate faithful images. The audit checks branch head and four V53 workflow names against the same SHA; if absent, it reports missing evidence rather than inventing success.
