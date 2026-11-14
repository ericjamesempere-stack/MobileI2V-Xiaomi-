---
title: MobileI2V Experimental Image Generator
emoji: 🎞️
colorFrom: blue
colorTo: purple
sdk: gradio
app_file: app.py
python_version: "3.10"
suggested_hardware: zero-a10g
---

# MobileI2V ZeroGPU prototype

Copy `zerogpu/app.py` to the root of a Hugging Face Gradio Space as `app.py`. Copy `backend/image_server.py` to `backend/image_server.py` (plus empty `backend/__init__.py`) and `zerogpu/requirements.txt` as `requirements.txt`. Select **ZeroGPU** hardware in Space settings. The `@spaces.GPU` decorator is required.

The Space UI is intended for **manual proof-of-concept testing**. The Godot client's existing `/generate` JSON protocol does **not** call this Gradio Space directly; an API adapter or a revised client is still needed. The model must download on first request and may fail due to compatibility, license, GPU queue or quota. Never place secrets in a public Space repository.

Check eligibility and quotas: https://huggingface.co/docs/hub/spaces-zerogpu
