# Native Android integration blockers (Godot 4.3)

## Verified architectural blocker

The current `export_presets.cfg` has `gradle_build/use_gradle_build=false`.
Godot Android plugin **v2** requires a Gradle build and an installed
Android build template. The project does not get a native singleton simply
because GDScript calls `Engine.get_singleton("ReferencePoseGenerator")`
or `Engine.get_singleton("MP4Exporter")`.

Source: https://docs.godotengine.org/en/4.3/tutorials/platform/android/android_plugin.html

## MP4 encoder: exact integration target

Implement a Godot 4.3 Android plugin v2 exposing `MP4Exporter` with:
- `begin(outputPath, width, height, fps)` (return success/error)
- `push_frame_rgba(bytes)` (return success/error)
- `finish()` (return verified MP4 path or error)

Use Android `MediaCodec` (H.264 AVC) + `MediaMuxer` (MP4).
Feed a supported encoder pixel format or render frames to an input Surface;
raw RGBA must **not** be assumed to be directly accepted by the codec.
Drain output buffers, add the track on OUTPUT_FORMAT_CHANGED, write
monotonic presentation timestamps, signal end-of-stream, stop/release
codec and muxer, and verify that the output file exists and is nonempty.
Use app-private storage first to avoid scoped-storage permission failures.
For the studio, encode its existing validated PNG frame paths, **not**
the unrelated legacy character rig in `scripts/export_mp4.gd`.

## Image model: exact integration target

Implement a distinct Godot Android plugin v2 exposing
`ReferencePoseGenerator.is_model_ready()` and
`ReferencePoseGenerator.generate_pose_png(requestJson, outputPath)`.
Its runtime must load real weights on-device, condition on BOTH
reference image and target pose, and write a new PNG. A pose estimator
alone does not satisfy this requirement. `PoseModelManifest` only
checks metadata and file existence; it does not verify model inference.
Do not set ready=true without an actual model and test inference.

## Build / release gates

1. Install the Godot 4.3 Android Gradle build template in `android/build`.
2. Package the native plugin(s) as Android plugin v2 and enable them.
3. Set `gradle_build/use_gradle_build=true` only once the template and
   plugin dependencies are actually installed; otherwise the APK build
   may fail.
4. Build ARM64 APK in CI and confirm each singleton is present at runtime.
5. Run a real input photo -> 2+ distinct pose PNGs -> full sequence ->
   H.264 MP4 test on the Xiaomi 14T Pro.
6. Verify video playback, orientation, duration, size, frame rate and
   source-photo identity visually. Until then: **not production ready**.

The current CI tests are headless Godot tests, not an Android device
runtime test. They cannot prove the Android plugin is installed.
