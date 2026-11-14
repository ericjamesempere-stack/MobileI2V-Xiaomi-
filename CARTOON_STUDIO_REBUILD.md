# Cartoon Studio — clean rebuild specification

This branch is the clean rebuild workspace. Legacy UI and demo character are not product entry points. Preserve old branch as a rollback only.

## One-screen user journey
1. Import one optional reference image (character, object, or background), saved locally with project.
2. Describe action/story in natural language; choose duration and frame rate (default 30 fps).
3. Tap **Générer** once. The system plans actions, poses, keyframes and intermediate drawings; displays real progress, estimated frame count, and errors.
4. On completion, automatically open **Assemblage** with a preview and a single **Valider et exporter MP4** action.
5. Save real H.264 MP4 to user-accessible storage; provide playback/share and resume after interruption.

No demo character, developer controls, or bottom toolbar with multiple actions on home screen.

## Rendering contract
- Duration D seconds, FPS F: output exactly round(D * F) frames; e.g. 5s at 30fps = 150 frames, 30s = 900, 5min = 9000.
- Unique drawings may be fewer than output frames if deliberate holds/on-twos are selected. Never claim interpolated or warped frames are AI-redrawn.
- Plan storyboard first: scene/action timeline, subject identity, proportions, background, pose transitions and timing.
- Generate real pose-to-pose redraws with identity/style consistency; fallback animation must be visibly labeled as fallback, not silently substituted.
- Batch and persist frames; avoid retaining thousands of full-resolution bitmaps in RAM.
- Assembly is disabled until every expected frame exists and passes dimensions/ordering checks.
- MP4 export must use actual Android encoder or report explicit failure; no fake file extension.

## Android acceptance tests
- Clean launch to import screen, no dancing demo.
- Import reference image, save and reopen project.
- Generate storyboard with expected frame count and at least visibly distinct poses (stand, walk, wave).
- Export 5-second MP4 at 30 fps, decode and count 150 frames; verify duration, dimensions and playback.
- Test cancellation, resume, missing frames, out-of-memory protection, and 30-second sequence.
- Distinguish procedural rig/warp from actual generative redraw, and test the latter separately.
- No private reference image committed to this public repository.

## Product constraint
Free to run on Xiaomi 14T Pro; no paid API requirement. A true generative redraw backend must be demonstrably available before calling the app complete.
