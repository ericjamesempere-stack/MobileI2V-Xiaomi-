"""Real diffusion-based image-to-image redraw service.
Requires separately installed open-source model weights and GPU/CPU resources.
Does not claim guaranteed identity preservation or zero-cost cloud inference.
Run: pip install -r ai_redraw/requirements.txt
     REDRAW_MODEL_ID=runwayml/stable-diffusion-v1-5 uvicorn ai_redraw.server:app --host 127.0.0.1 --port 8765
"""
import io
import os
from functools import lru_cache
from PIL import Image
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response

app = FastAPI(title="MobileI2V Reference Redraw", version="0.1")

@lru_cache(maxsize=1)
def get_pipeline():
    try:
        import torch
        from diffusers import AutoPipelineForImage2Image
    except ImportError as exc:
        raise RuntimeError("Install ai_redraw/requirements.txt") from exc
    model = os.environ.get("REDRAW_MODEL_ID", "stable-diffusion-v1-5/stable-diffusion-v1-5")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    pipe = AutoPipelineForImage2Image.from_pretrained(model, torch_dtype=dtype)
    pipe = pipe.to(device)
    pipe.set_progress_bar_config(disable=True)
    return pipe

def validate_image(raw: bytes) -> Image.Image:
    if len(raw) > 12 * 1024 * 1024:
        raise HTTPException(413, "Reference image exceeds 12 MB")
    try:
        image = Image.open(io.BytesIO(raw)).convert("RGB")
        image.load()
    except Exception as exc:
        raise HTTPException(422, "Invalid reference image") from exc
    if image.width < 32 or image.height < 32:
        raise HTTPException(422, "Reference image too small")
    return image

def redraw(reference: Image.Image, prompt: str, action: str, strength: float, seed: int) -> Image.Image:
    import torch
    pipe = get_pipeline()
    image = reference.copy()
    image.thumbnail((512, 512))
    width = max(64, round(image.width / 8) * 8)
    height = max(64, round(image.height / 8) * 8)
    image = image.resize((width, height))
    generator = torch.Generator(device=pipe.device).manual_seed(seed)
    result = pipe(
        prompt=f"{prompt}. Same character, same facial features, same hairstyle, same clothing and colors. Full body, {action}, coherent anatomy, clean manga illustration",
        negative_prompt="different person, changed outfit, duplicate limbs, extra fingers, blurry face, distorted anatomy",
        image=image,
        strength=strength,
        guidance_scale=7.0,
        num_inference_steps=24,
        generator=generator,
    )
    return result.images[0]

@app.get("/health")
def health():
    return {"ok": True, "engine": "diffusers_img2img", "model_loaded": get_pipeline.cache_info().currsize > 0}

@app.post("/redraw")
async def redraw_endpoint(
    reference: UploadFile = File(...),
    prompt: str = Form("manga character"),
    action: str = Form("standing"),
    strength: float = Form(0.55),
    seed: int = Form(1234),
):
    if not 0.1 <= strength <= 0.95:
        raise HTTPException(422, "strength must be between 0.1 and 0.95")
    if len(prompt) > 2000 or len(action) > 200:
        raise HTTPException(422, "prompt too long")
    image = validate_image(await reference.read())
    try:
        output = redraw(image, prompt, action, strength, seed)
    except Exception as exc:
        raise HTTPException(503, f"Model inference unavailable: {type(exc).__name__}") from exc
    buffer = io.BytesIO()
    output.save(buffer, format="PNG")
    return Response(buffer.getvalue(), media_type="image/png", headers={"X-Redraw-Engine": "diffusers-img2img"})

# Imported last to avoid circular imports: sequence uses redraw and validation above.
from .sequence import router as sequence_router
app.include_router(sequence_router)

from .pose import router as pose_router
app.include_router(pose_router)
