# MobileI2V — optional real generative drawing backend

This is an **integration of existing pretrained SDXL and IP-Adapter models**, not a newly trained model. It generates detailed images from text and optionally conditions on a reference photo. It does **not** guarantee facial identity, anatomical continuity, consistent poses, or free GPU availability.

## Setup (separate CUDA GPU computer/server)

1. Create a Python virtual environment and install `ai_backend/requirements.txt`. Install a CUDA-compatible PyTorch build according to your GPU/OS.
2. Download/authorize any gated model weights from their respective providers. Review the model and IP-Adapter licenses before use.
3. Start: `uvicorn ai_backend.server:app --host 127.0.0.1 --port 8000`
4. Check `GET /health`. Call `POST /generate` for one PNG or `POST /generate/storyboard` for a batch compatible with MobileI2V.
5. To access from Android, expose the server through **your own authenticated HTTPS reverse proxy**. Do not expose the unauthenticated GPU endpoint to the public Internet. In MobileI2V's advanced AI field, enter `https://your-secure-server/generate/storyboard`.

Input includes `prompt`, optional `image_base64`, `frames` (1–24) and `seed`. Output is a list of base64 PNG images. Start with 1–4 frames because SDXL at 768×1024 is resource-intensive. Use the same reference photo and character description across frames. Review each generated image manually; current implementation does not train a character LoRA or enforce pose geometry.

**Not an Android-local model.** Xiaomi 14T Pro does not have a supported CUDA runtime for this implementation. There is no guarantee of a zero-cost public GPU, nor unlimited generations. Offline procedural cartoon mode remains available without GPU.
