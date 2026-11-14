"""Sequential redraw using actual diffusion inference, with bounded resources.
Each output becomes the next input. A fixed seed reduces variation but does not
guarantee identity or correct pose. No automatic cloud uploads are performed.
"""
import io
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
):
    steps = [x.strip() for x in actions.split(",") if x.strip()]
    if not 1 <= len(steps) <= 8:
        raise HTTPException(422, "Sequence must contain 1 to 8 actions")
    if len(prompt) > 2000 or any(len(x) > 200 for x in steps):
        raise HTTPException(422, "Prompt too long")
    if not 0.1 <= strength <= 0.95:
        raise HTTPException(422, "Invalid strength")
    current = validate_image(await reference.read())
    outputs = []
    try:
        for index, action in enumerate(steps):
            current = redraw(current, prompt, action, strength, seed)
            buffer = io.BytesIO()
            current.save(buffer, format="PNG")
            outputs.append((f"frame_{index:03d}.png", buffer.getvalue()))
    except Exception as exc:
        raise HTTPException(503, f"Inference failed: {type(exc).__name__}") from exc
    import zipfile
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for name, data in outputs:
            z.writestr(name, data)
    archive.seek(0)
    return StreamingResponse(archive, media_type="application/zip",
                             headers={"Content-Disposition": 'attachment; filename="redraw_sequence.zip"'})
