# KARMA ONE — Step 11 final integration: execution contract

Created 2026-11-18. Base SHA: eed3e74303bf76b0f0aa524c7825640d73934659
Base branch: karma/step10-consolidation-safe-20261118
New integration branch: karma/step11-final-integration-20261118

## Verified baseline
- Successful ARM64 APK run: https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44294899825
- Artifact ID 14422947882; APK artifact is valid for the Step 10 SHA only.
- Successful Android and Godot CI: https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44285341418
- Step 9G ancestry preserved: 8b3a795ec900861c8878dfbdf3b7185efcf100b9

## Branches with divergent changes requiring code-level reconciliation
- karma/work-gallery-agent-generation-20261118 @ 92e412176a16359514ec92cee1773373ecc34c5d
- karma/v61-e01-auto-engine-fallback-20261118 @ 6b0892221e9fb9c67c72b8b32ca53ffbedc96a79
- Re-fetch branch heads before integrating; inspect successors.

GitHub comparison against Step 10 indicates 27 and 28 commits ahead respectively, with 26 Step 10 commits absent from each branch. Do not blindly merge, reset, or overwrite.

## Files requiring detailed review
.github/workflows/build-apk.yml
.github/workflows/verify-unified-merge.yml
addons/mp4exporter/plugin.gd
export_presets.cfg
native/mp4exporter/src/main/java/com/mobilei2v/encoder/MP4Exporter.java
native/mp4exporter/src/main/java/com/mobilei2v/encoder/ReferenceImagePickerActivity.java
native/mp4exporter/src/test/java/com/mobilei2v/encoder/ReferenceImageMailboxTest.java
scripts/GeneratedFrameValidator.gd
scripts/android_image_reader.gd
scripts/hf_studio_generator.gd
scripts/local_studio_generator.gd
scripts/storyboard.gd
scripts/studio_friendly_ui.gd
scripts/universal_board_pipeline.gd
tests/test_friendly_studio.gd
tests/test_generated_frame_validator.gd
tests/test_hf_batch_fallback.gd
tests/test_local_engine_probe.gd
tests/test_reference_review_pipeline.gd
tests/test_unified_storyboard_wiring.gd
tests/test_v58_photo_recovery.gd

## Required execution
1. Fetch and inspect all branches, merge bases and per-file changes.
2. Preserve all Step 9G/10 corrections and validated tests; port missing Work gallery and V61 fallback behavior into the existing code paths, without parallel implementations.
3. Verify Android gallery picker, image reader, agent protocol, image service error handling, local/remote fallback, storyboard continuity, approval gates and MP4 exporter.
4. Run focused tests plus complete Android and Godot CI. Report commands, results and exact SHA.
5. Update docs/KARMA_ONE_LOCKED_STEPS.md with evidence and limitations; lock Step 11 only when tests pass.
6. User authorized compiling a new ARM64 APK once integration and tests pass. Before building, inspect GitHub Actions for an existing run on the exact SHA. Do not duplicate/re-run any build. If tests fail, stop without building.
7. Publish exact run URL, artifact ID, expiry and SHA. Clearly separate CI validation from unverified on-device tests on Xiaomi 14T Pro.
8. Never represent a Step 10 APK as the Step 11 build.

## Status at creation
Step 11 branch exists and is based on tested Step 10 code. Integration, tests and Step 11 APK build are NOT yet completed. This document is a precise handoff, not a claim of implementation.
