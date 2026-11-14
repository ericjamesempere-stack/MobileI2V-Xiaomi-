# Real model validation — current limitations and reproducible steps

The existing Godot storyboard UI calls `POST /pose` and `POST /generate/storyboard`. The matching Python adapter is `tools/visual_backend.py`. This is **not** an Android-native model: it must run on a machine with Python and suitable models. No user image is sent to public GitHub.

## Prerequisites
- Python with `flask`, `pillow`, `numpy`, a compatible `mediapipe` build, and for redraw `torch`, `diffusers`, `transformers`, `accelerate`.
- A downloaded, license-compatible **image-to-image diffusion model** that is supported by `AutoPipelineForImage2Image`. Specify it in `MOBILEI2V_IMAGE_MODEL`; no weights are bundled.
- A secure network path between Android and the backend; do not expose the Flask development server to the internet. Use HTTPS/authentication in a production deployment.

## Start and test
```sh
export MOBILEI2V_IMAGE_MODEL='YOUR_COMPATIBLE_MODEL_ID'
python tools/visual_backend.py
curl http://127.0.0.1:8765/health
```
The Godot advanced field should point to `https://YOUR_SECURE_HOST/generate/storyboard`; the pose request derives `/pose` from the same base URL.

## Acceptance test with the real user reference (private)
1. On the test machine, open the user's own imported illustration; base64-encode it locally.
2. Call `POST /pose` and save returned 33 landmarks; visually overlay them on the source. If the pose is wrong or missing, mark **failed**; never substitute standing-silhouette estimates.
3. Call `POST /generate/storyboard` with the same image and a simple new-pose prompt, requesting 2 images. Inspect face, hair, clothing, hands and leg anatomy. Record failures.
4. Generate a 3-keyframe action with consistent reference and check continuity; only then interpolate and encode MP4.
5. Measure model latency, memory and storage. Test actual Android access separately.

## Known blockers
- MediaPipe `solutions.pose` is not present in all recent Python MediaPipe versions. The backend detects and reports this; use a compatible build or migrate to MediaPipe Tasks with a downloaded pose landmarker task file.
- Plain image-to-image diffusion does **not** preserve exact identity, handle hidden body regions, or guarantee consistent successive frames. A reference-conditioning architecture (e.g. IP-Adapter / pose conditioning, with model-specific compatible weights) and visual quality gates are needed.
- The user's illustration depicts a crouching person with occluded limbs; detection confidence may be poor.
- Free unlimited remote GPU generation is not available as a guarantee. No paid services should be enabled without permission.
- Existing CI validates code and synthetic visuals, **not** actual model inference or the Xiaomi GPU.

## Validation status
No successful MediaPipe inference or diffusion redraw on the user's illustration has been observed yet. Do not report the integration as working on-device.
