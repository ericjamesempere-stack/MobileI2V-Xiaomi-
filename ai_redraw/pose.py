"""Pose-conditioned reference redraw using SD1.5 ControlNet OpenPose.
Requires a compatible OpenPose skeleton image (black background, colored
skeleton). Unlike prompt-only img2img, this conditions the body pose explicitly.
It is still not an identity-locked face model; review every output.
"""
import io
import os
from functools import lru_cache
from PIL import Image
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from .server import validate_image

router = APIRouter()

@lru_cache(maxsize=1)
def get_pose_pipeline():
    import torch
    from diffusers import ControlNetModel, StableDiffusionControlNetImg2ImgPipeline
    model = os.getenv("REDRAW_MODEL_ID", "stable-diffusion-v1-5/stable-diffusion-v1-5")
    control_model = os.getenv("REDRAW_POSE_MODEL_ID", "lllyasviel/control_v11p_sd15_openpose")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    controlnet = ControlNetModel.from_pretrained(control_model, torch_dtype=dtype)
    pipe = StableDiffusionControlNetImg2ImgPipeline.from_pretrained(
        model, controlnet=controlnet, torch_dtype=dtype, safety_checker=None,
        requires_safety_checker=False,
    ).to(device)
    pipe.set_progress_bar_config(disable=True)
    return pipe

def pose_redraw(reference: Image.Image, pose: Image.Image, prompt: str, strength: float, seed: int) -> Image.Image:
    import torch
    pipe = get_pose_pipeline()
    image = reference.copy()
    image.thumbnail((512, 512))
    w = max(64, round(image.width / 8) * 8)
    h = max(64, round(image.height / 8) * 8)
    image = image.resize((w, h))
    pose = pose.resize((w, h), Image.Resampling.NEAREST)
    generator = torch.Generator(device=pipe.device).manual_seed(seed)
    return pipe(
        prompt=f"{prompt}, same recognizable character, identical outfit, manga illustration",
        negative_prompt="extra limbs, missing limbs, changed clothes, deformed face",
        image=image,
        control_image=pose,
        strength=strength,
        controlnet_conditioning_scale=1.0,
        guidance_scale=7.0,
        num_inference_steps=25,
        generator=generator,
    ).images[0]

@router.post("/redraw/pose")
async def pose_endpoint(
    reference: UploadFile = File(...),
    pose: UploadFile = File(...),
    prompt: str = Form("same character, full body"),
    strength: float = Form(0.65),
    seed: int = Form(1234),
):
    if not 0.1 <= strength <= 0.95 or len(prompt) > 2000:
        raise HTTPException(422, "Invalid generation parameters")
    original = validate_image(await reference.read())
    skeleton = validate_image(await pose.read())
    try:
        output = pose_redraw(original, skeleton, prompt, strength, seed)
    except Exception as exc:
        raise HTTPException(503, f"Pose model unavailable: {type(exc).__name__}") from exc
    buffer = io.BytesIO()
    output.save(buffer, format="PNG")
    return Response(buffer.getvalue(), media_type="image/png", headers={
        "X-Redraw-Engine": "controlnet-openpose-img2img",
        "X-Identity-Verified": "false",
    })

@router.post("/redraw/action")
async def action_endpoint(
    reference: UploadFile = File(...),
    action: str = Form("running"),
    phase: float = Form(0.5),
    prompt: str = Form("same character, full body"),
    strength: float = Form(0.65),
    seed: int = Form(1234),
):
    from .pose_guides import render_pose
    if not 0.0 <= phase <= 1.0 or not 0.1 <= strength <= 0.95:
        raise HTTPException(422, "Invalid phase or strength")
    if len(action) > 200 or len(prompt) > 2000:
        raise HTTPException(422, "Prompt too long")
    original = validate_image(await reference.read())
    skeleton = render_pose(action, phase)
    try:
        output = pose_redraw(original, skeleton, prompt + ", " + action, strength, seed)
    except Exception as exc:
        raise HTTPException(503, f"Pose inference unavailable: {type(exc).__name__}") from exc
    buffer = io.BytesIO()
    output.save(buffer, format="PNG")
    return Response(buffer.getvalue(), media_type="image/png", headers={
        "X-Redraw-Engine": "controlnet-generated-pose",
        "X-Identity-Verified": "false",
    })
