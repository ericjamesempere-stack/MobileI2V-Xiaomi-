"""Experimental ZeroGPU ControlNet image-to-image endpoint for MobileI2V."""
import base64
import io
import os
from PIL import Image
import gradio as gr
import spaces
import torch
from diffusers import StableDiffusionControlNetImg2ImgPipeline, ControlNetModel

MAX_BYTES = 5_000_000
BASE = "runwayml/stable-diffusion-v1-5"
CONTROL = "lllyasviel/control_v11p_sd15_openpose"

controlnet = ControlNetModel.from_pretrained(CONTROL, torch_dtype=torch.float16)
pipe = StableDiffusionControlNetImg2ImgPipeline.from_pretrained(
    BASE, controlnet=controlnet, torch_dtype=torch.float16, safety_checker=None
)
pipe.to("cuda")
pipe.enable_attention_slicing()

def decode_png(encoded):
    raw = base64.b64decode(encoded, validate=True)
    if len(raw) > MAX_BYTES:
        raise gr.Error("Image trop volumineuse")
    image = Image.open(io.BytesIO(raw))
    image.load()
    if max(image.size) > 1536:
        raise gr.Error("Image trop grande")
    return image.convert("RGB").resize((384, 512))

@spaces.GPU(duration=60)
def redraw(reference_base64, pose_base64, instruction):
    if not instruction.strip():
        raise gr.Error("Mouvement manquant")
    source = decode_png(reference_base64)
    pose = decode_png(pose_base64)
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
