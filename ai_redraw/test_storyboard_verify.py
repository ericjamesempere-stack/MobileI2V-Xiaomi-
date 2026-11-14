import io
import json
import zipfile
import pytest
from PIL import Image, ImageDraw
from ai_redraw.storyboard_plan import plan_storyboard
from ai_redraw.storyboard_sheets import create_storyboard_archive
from ai_redraw.storyboard_verify import verify_storyboard_archive

def archive():
    plan = plan_storyboard("A train passes. Clouds roll in.", 2, 4, 128, 128)
    def render(index, *_):
        frame = Image.new("RGB", (128, 128), "navy")
        ImageDraw.Draw(frame).rectangle((index * 8, 10, index * 8 + 9, 30), fill="yellow")
        return frame
    return create_storyboard_archive(plan, render, sheet_columns=2)

def rewrite(raw, changes):
    out = io.BytesIO()
    with zipfile.ZipFile(io.BytesIO(raw)) as src, zipfile.ZipFile(out, "w") as dst:
        for name in src.namelist():
            dst.writestr(name, changes.get(name, src.read(name)))
    return out.getvalue()

def test_complete_archive_passes():
    result = verify_storyboard_archive(archive())
    assert result["valid"] and result["total_frames"] == 8
    assert result["unique_drawings"] == 8
    assert result["identity_verified"] is False

def test_modified_frame_is_rejected():
    raw = archive()
    with pytest.raises(ValueError, match="Corrupted frame"):
        verify_storyboard_archive(rewrite(raw, {"frames/frame_000002.png": b"fake"}))

def test_missing_frame_is_rejected():
    raw = archive()
    with zipfile.ZipFile(io.BytesIO(raw)) as src:
        manifest = json.loads(src.read("manifest.json"))
    manifest["frames"].pop()
    with pytest.raises(ValueError, match="Incomplete storyboard"):
        verify_storyboard_archive(rewrite(raw, {"manifest.json": json.dumps(manifest).encode()}))

def test_repeated_visual_content_is_rejected():
    raw = archive()
    with zipfile.ZipFile(io.BytesIO(raw)) as src:
        manifest = json.loads(src.read("manifest.json"))
        repeated = src.read("frames/frame_000000.png")
    import hashlib
    manifest["frames"][2]["sha256"] = hashlib.sha256(repeated).hexdigest()
    changed = rewrite(raw, {"frames/frame_000002.png": repeated,
                            "manifest.json": json.dumps(manifest).encode()})
    with pytest.raises(ValueError, match="Repeated drawings"):
        verify_storyboard_archive(changed)
