import gradio as gr
import spaces
from PIL import Image
from functools import lru_cache
import re
from diffusers import AutoPipelineForImage2Image
import torch


@lru_cache(maxsize=1)
def pipeline():
    dtype = torch.float16 if torch.cuda.is_available() else torch.float32
    model = AutoPipelineForImage2Image.from_pretrained("stabilityai/sd-turbo", torch_dtype=dtype)
    model.to("cuda" if torch.cuda.is_available() else "cpu")
    model.set_progress_bar_config(disable=True)
    return model


def fit(image):
    scale = min(512 / image.width, 512 / image.height)
    width = max(64, round(image.width * scale / 8) * 8)
    height = max(64, round(image.height * scale / 8) * 8)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def action_stage(story, progress):
    parts = [x.strip() for x in re.split(r"(?i)\b(?:et puis|puis|ensuite|then|afterwards|suddenly)\b|[.;\n]", story) if x.strip()]
    return parts[min(len(parts) - 1, int(min(max(progress, 0), 0.99999) * len(parts)))] if parts else story

@spaces.GPU(duration=45)
def generate(reference, previous, story, frame_index, total_frames, reference_strength):
    if reference is None:
        raise gr.Error("Reference image required")
    if not story or not story.strip():
        raise gr.Error("Movement description required")
    ref = fit(reference.convert("RGB"))
    prev = fit(previous.convert("RGB")) if previous is not None else ref
    if prev.size != ref.size:
        prev = prev.resize(ref.size, Image.Resampling.LANCZOS)
    conditioning = Image.blend(prev, ref, min(0.4, max(0.1, reference_strength * 0.35)))
    phase = frame_index / max(1, total_frames)
    stage = action_stage(story, phase)
    prompt = f"{story}. Current action: {stage}. Frame {frame_index+1}/{total_frames}. Same character, same clothing, new pose."
    with torch.inference_mode():
        output = pipeline()(prompt=prompt, image=conditioning, strength=0.55, guidance_scale=0.0, num_inference_steps=2).images[0]
    return output

demo = gr.Interface(
    fn=generate,
    inputs=[
        gr.Image(type="pil", label="Reference"),
        gr.Image(type="pil", label="Previous frame (optional)"),
        gr.Textbox(label="Story", value="The character walks then starts running"),
        gr.Slider(0, 119, step=1, value=0, label="Frame index"),
        gr.Slider(2, 120, step=1, value=12, label="Total frames"),
        gr.Slider(0, 1, value=0.85, label="Reference strength"),
    ],
    outputs=gr.Image(type="pil", label="New generated frame"),
    title="MobileI2V — experimental SD-Turbo img2img",
    description="Free ZeroGPU test, subject to daily quotas. Does not guarantee identity or motion continuity.",
)
if __name__ == "__main__":
    demo.queue().launch()
