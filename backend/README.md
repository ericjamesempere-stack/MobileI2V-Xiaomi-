# MobileI2V image-to-image backend (experimental)

This is a **real diffusion image generator**, not a video or pose model. The Android Godot app sends an original PNG, the previous generated PNG, and a free-form prompt. The server returns a new PNG for each frame.

## Run (on a machine with sufficient RAM / preferably NVIDIA GPU)

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.image_server:app --host 127.0.0.1 --port 7860
```

Model downloads happen on first request. Default model: `stabilityai/sd-turbo`; check its license and availability before use. No commercial API is required, but computing power, hosting and data transfer are **not guaranteed free**. CPU inference can be extremely slow. A Xiaomi phone is **not** assumed capable of running this Python backend.

For Android access, deploy behind your own **HTTPS reverse proxy**. In the application's advanced storyboard options enter `https://your-host/generate` and select **Generer images successives (moteur HTTPS)**. Do not publicly expose the unauthenticated endpoint: it accepts expensive GPU jobs and potentially sensitive user images. Add authentication, TLS, request limits, and delete uploaded image data appropriately before any public deployment.

## Limitations

SD-Turbo image-to-image is not an animation model. It **cannot reliably** follow a motion trajectory, preserve a face, synthesize unseen body parts or create a seamless dance loop. Each image is newly generated, but reference anchoring is heuristic. The output is an experimental integration milestone, **not** a finished arbitrary-motion generator. For reliable animation, replace the backend with a motion-conditioned image/video model and test temporal consistency. Current frame count 2–120; the Godot exporter may interpolate further frames.

The JSON contract matches `scripts/image_sequence_generator.gd`. Health check: `GET /health`. Generation: `POST /generate`.
