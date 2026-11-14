"""Disk-backed storyboard creation: constant frame-memory, atomic output.

For long productions this avoids retaining thousands of full-resolution PIL
images or the final ZIP in RAM. Requires a real renderer; no synthetic fallback.
"""
from pathlib import Path
from tempfile import NamedTemporaryFile
from zipfile import ZipFile, ZIP_DEFLATED
from io import BytesIO
import hashlib
import json
import os
from PIL import Image, ImageChops, ImageStat, ImageDraw
from .drawing_generator import FrameRequest
from .storyboard_plan import plan_storyboard

def produce_storyboard_to_file(reference, story, renderer, destination, *,
                               duration_seconds=5, fps=24, width=720, height=1280,
                               columns=4, max_mean_change=100.0):
    if not isinstance(reference, Image.Image):
        raise ValueError("Reference image is required")
    if not callable(renderer):
        raise ValueError("A working drawing renderer is required")
    if not 1 <= columns <= 8:
        raise ValueError("Invalid sheet columns")
    plan = plan_storyboard(story, duration_seconds, fps, width, height)
    target = Path(destination)
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = NamedTemporaryFile(dir=target.parent, suffix=".partial", delete=False)
    tmp_path = Path(tmp.name)
    tmp.close()
    original = reference.convert("RGB").copy()
    previous = None
    hashes = set()
    scene_index = 0
    thumb_width = 160
    thumb_height = max(1, round(thumb_width * height / width))
    rows = 4
    sheet_size = columns * rows
    sheet = None
    manifest = {"schema_version": 2, "fps": fps, "width": width,
                "height": height, "total_frames": plan.total_frames,
                "scenes": [s.__dict__ for s in plan.scenes],
                "sheet_columns": columns, "sheet_rows": rows, "frames": []}
    try:
        with ZipFile(tmp_path, "w", compression=ZIP_DEFLATED,
                     compresslevel=3, allowZip64=True) as archive:
            for index in range(plan.total_frames):
                while (scene_index + 1 < len(plan.scenes) and
                       index >= plan.scenes[scene_index + 1].start_frame):
                    scene_index += 1
                scene = plan.scenes[scene_index]
                request = FrameRequest(
                    index, scene_index, scene.instruction,
                    (index - scene.start_frame) / max(1, scene.frame_count - 1),
                    fps, width, height, original.copy(),
                    previous.copy() if previous is not None else None)
                frame = renderer(request)
                if not isinstance(frame, Image.Image) or frame.size != (width, height):
                    raise ValueError(f"Invalid drawing at frame {index}")
                frame = frame.convert("RGB")
                digest = hashlib.sha256(frame.tobytes()).digest()
                if digest in hashes:
                    raise ValueError(f"Repeated drawing at frame {index}")
                if previous is not None:
                    a = previous.resize((64, 64), Image.Resampling.BILINEAR)
                    b = frame.resize((64, 64), Image.Resampling.BILINEAR)
                    difference = ImageChops.difference(a, b)
                    change = sum(ImageStat.Stat(difference).mean) / 3
                    if change > max_mean_change:
                        raise ValueError(f"Visual discontinuity at frame {index}")
                hashes.add(digest)
                previous = frame
                encoded = BytesIO()
                frame.save(encoded, format="PNG")
                data = encoded.getvalue()
                name = f"frames/frame_{index:06d}.png"
                archive.writestr(name, data)
                manifest["frames"].append({
                    "index": index, "scene": scene_index, "file": name,
                    "sha256": hashlib.sha256(data).hexdigest()})
                slot = index % sheet_size
                if slot == 0:
                    sheet = Image.new("RGB",
                        (columns * thumb_width, rows * (thumb_height + 24)), "white")
                x = slot % columns * thumb_width
                y = slot // columns * (thumb_height + 24)
                thumb = frame.resize((thumb_width, thumb_height), Image.Resampling.LANCZOS)
                sheet.paste(thumb, (x, y))
                ImageDraw.Draw(sheet).text((x + 3, y + thumb_height + 2),
                                            f"#{index:06d}", fill="black")
                if slot == sheet_size - 1 or index == plan.total_frames - 1:
                    board = BytesIO()
                    sheet.save(board, format="PNG")
                    archive.writestr(f"boards/board_{index // sheet_size:04d}.png",
                                     board.getvalue())
            archive.writestr("manifest.json",
                             json.dumps(manifest, ensure_ascii=False, indent=2))
        os.replace(tmp_path, target)
    except BaseException:
        tmp_path.unlink(missing_ok=True)
        raise
    return {"path": str(target), "total_frames": plan.total_frames,
            "scene_count": len(plan.scenes), "unique_drawings": len(hashes),
            "identity_verified": False, "artistic_quality_verified": False}
