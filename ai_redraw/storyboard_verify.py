"""Validate finished storyboard archives before video assembly.

Checks every numbered frame, cryptographic integrity, geometry, temporal
coverage, and nonadjacent duplicate drawings. This cannot certify that the
drawing faithfully depicts the reference; that needs visual/model evaluation.
"""
import hashlib
import io
import json
import zipfile
from PIL import Image

def verify_storyboard_archive(raw: bytes) -> dict:
    if not raw:
        raise ValueError("Empty storyboard archive")
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        names = z.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP member names")
        if "manifest.json" not in names:
            raise ValueError("Missing storyboard manifest")
        manifest = json.loads(z.read("manifest.json"))
        count = manifest["total_frames"]
        width, height, fps = manifest["width"], manifest["height"], manifest["fps"]
        if not (1 <= count <= 18000 and 64 <= width <= 4096 and
                64 <= height <= 4096 and 1 <= fps <= 60):
            raise ValueError("Invalid storyboard dimensions or frame budget")
        frames = manifest["frames"]
        if len(frames) != count:
            raise ValueError("Incomplete storyboard")
        scene_cursor = 0
        for scene in manifest["scenes"]:
            if scene["start_frame"] != scene_cursor or scene["frame_count"] <= 0:
                raise ValueError("Scene coverage gap")
            scene_cursor += scene["frame_count"]
        if scene_cursor != count:
            raise ValueError("Scene coverage does not match frame count")
        seen = set()
        repeated = []
        for i, entry in enumerate(frames):
            name = f"frames/frame_{i:06d}.png"
            if entry["index"] != i or entry["file"] != name or name not in names:
                raise ValueError(f"Missing or out-of-order frame {i}")
            payload = z.read(name)
            if hashlib.sha256(payload).hexdigest() != entry["sha256"]:
                raise ValueError(f"Corrupted frame {i}")
            with Image.open(io.BytesIO(payload)) as image:
                if image.format != "PNG" or image.size != (width, height):
                    raise ValueError(f"Wrong frame format or geometry {i}")
                image.load()
                visual_hash = hashlib.sha256(image.convert("RGB").tobytes()).digest()
            if visual_hash in seen:
                repeated.append(i)
            seen.add(visual_hash)
        if repeated:
            raise ValueError(f"Repeated drawings at frames: {repeated[:12]}")
        per_sheet = manifest.get("sheet_columns", 4) * manifest.get("sheet_rows", 4)
        if not 1 <= per_sheet <= 48:
            raise ValueError("Invalid sheet layout")
        expected_sheets = (count + per_sheet - 1) // per_sheet
        actual_sheets = [n for n in names if n.startswith("boards/") and n.endswith(".png")]
        if len(actual_sheets) != expected_sheets:
            raise ValueError("Missing contact sheets")
        return {"valid": True, "total_frames": count, "fps": fps,
                "duration_seconds": count / fps, "scene_count": len(manifest["scenes"]),
                "unique_drawings": len(seen), "identity_verified": False}
