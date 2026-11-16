"""Experimental Gradio ZeroGPU pose-conditioned image redraw service."""
import base64
import io
from functools import lru_cache

import gradio as gr
import spaces
import torch
from PIL import Image
from diffusers import StableDiffusionControlNetImg2ImgPipeline, ControlNetModel

MAX_BYTES = 5_000_000
BASE = "stable-diffusion-v1-5/stable-diffusion-v1-5"
CONTROL = "lllyasviel/control_v11p_sd15_openpose"

@lru_cache(maxsize=1)
def get_pipeline():
    # Never call .to("cuda") at import time: ZeroGPU assigns a GPU only
    # inside a @spaces.GPU function invocation.
    controlnet = ControlNetModel.from_pretrained(CONTROL, torch_dtype=torch.float16)
    pipe = StableDiffusionControlNetImg2ImgPipeline.from_pretrained(
        BASE, controlnet=controlnet, torch_dtype=torch.float16
    )
    pipe.enable_attention_slicing()
    return pipe

def decode_png(encoded):
    try:
        raw = base64.b64decode(encoded, validate=True)
        if len(raw) > MAX_BYTES:
            raise ValueError("Image trop volumineuse")
        image = Image.open(io.BytesIO(raw))
        image.load()
        if max(image.size) > 1536:
            raise ValueError("Image trop grande")
        return image.convert("RGB").resize((384, 512))
    except (ValueError, OSError) as exc:
        raise gr.Error("Image invalide: " + str(exc)) from exc

@spaces.GPU(duration=120)
def redraw(reference_base64, pose_base64, instruction):
    if not instruction or not instruction.strip():
        raise gr.Error("Mouvement manquant")
    source = decode_png(reference_base64)
    pose = decode_png(pose_base64)
    pipe = get_pipeline()
    pipe.to("cuda")
    prompt = ("Same character identity, same hairstyle, same outfit, "
              "consistent character design, full body, " + instruction[:450])
    with torch.inference_mode():
        output = pipe(
            prompt=prompt,
            negative_prompt="different person, changed outfit, deformed limbs, extra arms, text",
            image=source,
            control_image=pose,
            strength=0.65,
            controlnet_conditioning_scale=1.0,
            guidance_scale=7.0,
            num_inference_steps=16,
        ).images[0]
    buffer = io.BytesIO()
    output.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode("ascii")

demo = gr.Interface(
    fn=redraw,
    inputs=[gr.Textbox(label="Reference PNG base64"), gr.Textbox(label="Pose PNG base64"), gr.Textbox(label="Movement")],
    outputs=gr.Textbox(label="Generated PNG base64"),
    api_name="redraw",
    title="MobileI2V Pose Redraw - experimental",
)
demo.queue().launch()
