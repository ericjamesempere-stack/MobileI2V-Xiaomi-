"""Generate pose sequences with explicit identity-drift controls.
Default 'reference' mode reuses the ORIGINAL reference for each pose instead of
feeding progressively altered faces back into diffusion. This reduces
compounding drift but does not guarantee likeness or precise pose control.
"""
import io
import json
import zipfile
from PIL import Image
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse
from .server import redraw, validate_image

router = APIRouter()

@router.post("/redraw/sequence")
async def redraw_sequence(
    reference: UploadFile = File(...),
    prompt: str = Form("same manga character"),
    actions: str = Form("standing,running,falling"),
    strength: float = Form(0.45),
    seed: int = Form(1234),
    identity_mode: str = Form("reference"),
):
    steps = [x.strip() for x in actions.split(",") if x.strip()]
    if not 1 <= len(steps) <= 8:
        raise HTTPException(422, "Sequence must contain 1 to 8 actions")
    if len(prompt) > 2000 or any(len(x) > 200 for x in steps):
        raise HTTPException(422, "Prompt too long")
    if not 0.1 <= strength <= 0.95:
        raise HTTPException(422, "Invalid strength")
    if identity_mode not in ("reference", "previous"):
        raise HTTPException(422, "identity_mode must be reference or previous")
    original = validate_image(await reference.read())
    current = original
    outputs = []
    try:
        for index, action in enumerate(steps):
            source = original if identity_mode == "reference" else current
            current = redraw(source, prompt, action, strength, seed)
            if not isinstance(current, Image.Image) or current.width < 32 or current.height < 32:
                raise ValueError("Invalid model output")
            buffer = io.BytesIO()
            current.save(buffer, format="PNG")
            outputs.append((f"frame_{index:03d}.png", buffer.getvalue()))
    except Exception as exc:
        raise HTTPException(503, f"Inference failed: {type(exc).__name__}") from exc
    manifest = {
        "engine": "diffusers_img2img",
        "actions": steps,
        "identity_mode": identity_mode,
        "strength": strength,
        "seed": seed,
        "identity_verified": False,
        "pose_verified": False,
        "note": "Model output must be reviewed; pose and likeness are not guaranteed.",
    }
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for name, data in outputs:
            z.writestr(name, data)
        z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
    archive.seek(0)
    return StreamingResponse(
        archive, media_type="application/zip",
        headers={"Content-Disposition": 'attachment; filename="redraw_sequence.zip"'},
    )
