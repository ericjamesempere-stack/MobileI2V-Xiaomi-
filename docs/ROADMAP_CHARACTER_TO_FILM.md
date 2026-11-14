# MobileI2V — character-to-film implementation plan

## Non-negotiable acceptance test
Import the user's crouching illustrated character locally (never commit private reference imagery to a public repository). Enter: "Le personnage se relève, se transforme en dragon, prend le métro puis joue au football". Generate a coherent shot list, reference-preserving keyframes, interpolated frames, and a playable MP4. Review frames for character identity, anatomy, continuity and correct actions. An APK build or synthetic stick-figure preview is **not** a pass.

## Existing reusable code
- scripts/character_separator.gd: alpha-preserving foreground extraction for simple backgrounds; offline GrabCut tool handles complex backgrounds outside Android.
- scripts/continuous_rig.gd: consumes 33 MediaPipe-style landmarks, but no verified on-device detector.
- scripts/two_bone_ik.gd and scripts/painted_limb_warp.gd: 2D limb animation; do not solve new camera angles or transformations.
- scripts/story_motion_planner.gd / story_director.gd: story segmentation foundation.
- scripts/export_mp4.gd: Android MP4 exporter with PNG fallback; verify actual device playback.

## Implementation stages (in order)
1. **Character extraction and identity**: import alpha or segment subject, save cutout and original, foreground mask, appearance palette, silhouette and immutable reference ID. Preserve user image privately. Add a quality gate for hair/limbs and overlapping foreground.
2. **Real pose acquisition**: Android Godot v2 plugin exposing an actual tested pose detector. Validate landmarks in source-image coordinates; reject low-confidence or occluded joints. For crouching and self-occlusion, use user-correctable landmark UI, not standing-silhouette guesses.
3. **Pose-conditioned rendering**: separate layers (torso, head, left/right arms, left/right legs) with occlusion order, joints and preserved texture. Generate a crouch-to-stand sequence and inspect every keyframe. Do not claim true reconstruction from 2D warping alone.
4. **Storyboard and action grammar**: parse arbitrary text into a structured scene list with actors, environment, actions, temporal dependencies and transformations. Keep original user text. A transformation must request novel generated keyframes, not force an IK rig.
5. **Novel-view and transformation backend**: pluggable local/on-device models where measurable and optional remote free providers only with user approval and within terms/quotas. Require reference-conditioned outputs and frame consistency checks. No guaranteed unlimited free photorealistic generation.
6. **Frame production**: keyframes -> pose/motion interpolation -> visual inspection -> batches of PNG frames -> H.264 MP4. 30 fps => 150 frames/5 seconds, 1800/minute. Interpolation is not sufficient for previously unseen views/objects; route those to visual generation.
7. **Resource management**: cache intermediate images, bounded batches, cancellation/resume, local disk budget, thermal/memory telemetry, explicit failure messages and recoverable exports.

## Quality gates
- Input is the actual user-selected illustration, not a synthetic placeholder.
- Character identity preserved across frames unless the story requests a change.
- Crouch-to-stand anatomically plausible, no dislocated limbs or major texture tearing.
- Transformation into dragon has distinct source, transitional and target keyframes.
- Subway and football scenes include relevant settings and actions.
- Exported MP4 is decodable and duration/frame count verified.
- Xiaomi 14T Pro test is marked unverified until actually run there.

## Architecture
Godot UI/orchestrator -> segmentation + pose adapter (Android native plugin / offline prototype) -> persistent character asset -> scene/action director -> per-shot renderer selection [rigged 2D | generative keyframes] -> interpolation/compositing -> frame cache -> Android MediaCodec MP4 muxer.

## Current status
CI Godot and Android builds succeeded at aba3b025, but no end-to-end test using the user's image and no verified transformation renderer. This file is a development contract, not a claim of implemented functionality.
