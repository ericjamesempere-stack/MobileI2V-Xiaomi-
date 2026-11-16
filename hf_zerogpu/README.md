---
title: MobileI2V Pose Redraw
emoji: 🎞️
colorFrom: blue
colorTo: purple
sdk: gradio
sdk_version: 5.49.1
app_file: app.py
pinned: false
---
# MobileI2V Pose Redraw (prototype)

Gradio ZeroGPU backend for pose-guided **image-to-image** rendering. The first image supplies the appearance; the second is an OpenPose-style guide. Uses Stable Diffusion 1.5 + ControlNet OpenPose. This is an experimental implementation, not verified on ZeroGPU or with the Android client. Identity fidelity is not guaranteed.

The Gradio API exposes `/redraw` with three inputs: source PNG base64, pose PNG base64, and movement description. It returns PNG base64. It is **not** a drop-in replacement for MobileI2V's custom JSON HTTP endpoint; a Gradio queue adapter must be implemented and tested first.

For an eligible Hugging Face account, create a Gradio ZeroGPU Space and upload these files. Select ZeroGPU hardware. Free quota applies. No token should be committed to this repository.
