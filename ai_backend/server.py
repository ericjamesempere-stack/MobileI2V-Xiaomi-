"""Optional GPU image generation service for MobileI2V.

Requires an independently available CUDA GPU and downloaded model weights.
No paid service, account bypass, or guaranteed free GPU is implied.
The service holds one identity reference image and a fixed palette/style
description across the sequence. This improves consistency but does not
guarantee exact facial identity.
"""
import base64
import io
import os
import threading
from functools import lru_cache

import torch
from diffusers import AutoPipelineForText2Image
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from PIL import Image

app = FastAPI(title="MobileI2V image generator")
lock = threading.Lock()
MODEL_ID = os.environ.get("MOBILEI2V_MODEL_ID", "stabilityai/stable-diffusion-xl-base-1.0")
IP_ADAPTER_REPO = os.environ.get("MOBILEI2V_IP_ADAPTER_REPO", "h94/IP-Adapter")
IP_ADAPTER_WEIGHT = os.environ.get("MOBILEI2V_IP_ADAPTER_WEIGHT", "ip-adapter_sdxl.bin")


class GenerateRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=2000)
    negative_prompt: str = "extra fingers, deformed limbs, distorted face, different outfit, inconsistent colors"
    reference_image_base64: str | None = None
    character_description: str = ""
    scene_description: str = ""
    seed: int = Field(default=42, ge=0, le=2147483647)
    width: int = Field(default=768, ge=256, le=1024)
    height: int = Field(default=1024, ge=256, le=1024)
    steps: int = Field(default=25, ge=1, le=60)
    identity_strength: float = Field(default=0.65, ge=0, le=1)


@lru_cache(maxsize=1)
def pipeline():
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA GPU required for this optional SDXL backend")
    pipe = AutoPipelineForText2Image.from_pretrained(
        MODEL_ID, torch_dtype=torch.float16, use_safetensors=True
    ).to("cuda")
    pipe.enable_attention_slicing()
    return pipe


def load_reference(encoded: str) -> Image.Image:
    raw = base64.b64decode(encoded, validate=True)
    if len(raw) > 12 * 1024 * 1024:
        raise ValueError("Reference image exceeds 12 MiB")
    image = Image.open(io.BytesIO(raw))
    image.verify()
    return Image.open(io.BytesIO(raw)).convert("RGB")


@app.get("/health")
def health():
    return {"service": "MobileI2V SDXL", "cuda_available": torch.cuda.is_available(),
            "model": MODEL_ID, "reference_supported": True}


@app.post("/generate")
def generate(req: GenerateRequest):
    if req.width % 8 or req.height % 8:
        raise HTTPException(400, "Dimensions must be multiples of 8")
    try:
        reference = load_reference(req.reference_image_base64) if req.reference_image_base64 else None
    except Exception as exc:
        raise HTTPException(400, f"Invalid reference image: {exc}") from exc
    with lock:
        try:
            pipe = pipeline()
            if reference is not None and not getattr(pipe, "_mobilei2v_ip_adapter_loaded", False):
                pipe.load_ip_adapter(
                    IP_ADAPTER_REPO, subfolder="sdxl_models", weight_name=IP_ADAPTER_WEIGHT
                )
                pipe._mobilei2v_ip_adapter_loaded = True
            if getattr(pipe, "_mobilei2v_ip_adapter_loaded", False):
                pipe.set_ip_adapter_scale(req.identity_strength if reference is not None else 0.0)
            text = ", ".join(filter(None, [
                req.character_description, req.scene_description, req.prompt,
                "high quality 2D animated film illustration, clean detailed linework, consistent costume"
            ]))
            kwargs = dict(
                prompt=text, negative_prompt=req.negative_prompt,
                width=req.width, height=req.height, num_inference_steps=req.steps,
                generator=torch.Generator(device="cuda").manual_seed(req.seed)
            )
            if reference is not None:
                kwargs["ip_adapter_image"] = reference
            image = pipe(**kwargs).images[0]
            output = io.BytesIO()
            image.save(output, format="PNG")
            return {"image_base64": base64.b64encode(output.getvalue()).decode("ascii"),
                    "seed": req.seed, "model": MODEL_ID,
                    "reference_used": reference is not None}
        except Exception as exc:
            raise HTTPException(503, f"Generation unavailable: {exc}") from exc
