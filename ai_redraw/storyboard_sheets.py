"""Lossless storyboard production with identity-preserving reference metadata.

A drawing provider generates each frame. This component never invents content.
Sheets preserve full frame proportions (no crop), validate scene coverage,
and record frame hashes for reproducibility and downstream assembly.
"""
import hashlib
import io
import json
import zipfile
from collections.abc import Callable
from PIL import Image, ImageDraw
from .storyboard_plan import StoryboardPlan

def create_storyboard_archive(plan: StoryboardPlan,
                              draw_frame: Callable[[int, str, int], Image.Image],
                              sheet_columns: int = 4,
                              thumbnail_width: int = 180) -> bytes:
    if not 1 <= sheet_columns <= 12 or not 64 <= thumbnail_width <= 512:
        raise ValueError("Invalid contact sheet layout")
    if not 1 <= plan.total_frames <= 18000:
        raise ValueError("Invalid frame budget")
    if not plan.scenes or sum(s.frame_count for s in plan.scenes) != plan.total_frames:
        raise ValueError("Scene plan does not cover all frames")
    expected = 0
    for s in plan.scenes:
        if s.start_frame != expected or s.frame_count <= 0:
            raise ValueError("Scene plan has gaps or overlaps")
        expected += s.frame_count
    sheet_rows = 4
    per_sheet = sheet_columns * sheet_rows
    thumb_height = max(1, round(thumbnail_width * plan.height / plan.width))
    cell_height = thumb_height + 28
    manifest = {"schema_version": 2, "fps": plan.fps, "width": plan.width,
                "height": plan.height, "total_frames": plan.total_frames,
                "scenes": [s.__dict__ for s in plan.scenes], "frames": []}
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=3, allowZip64=True) as archive:
        scene_id = 0
        sheet = None
        for index in range(plan.total_frames):
            while scene_id + 1 < len(plan.scenes) and index >= plan.scenes[scene_id + 1].start_frame:
                scene_id += 1
            scene = plan.scenes[scene_id]
            frame = draw_frame(index, scene.instruction, index - scene.start_frame)
            if not isinstance(frame, Image.Image):
                raise ValueError(f"Drawing generator returned no image at frame {index}")
            if frame.size != (plan.width, plan.height):
                raise ValueError(f"Wrong proportions at frame {index}: {frame.size}")
            frame = frame.convert("RGB")
            encoded = io.BytesIO()
            frame.save(encoded, "PNG")
            payload = encoded.getvalue()
            name = f"frames/frame_{index:06d}.png"
            archive.writestr(name, payload)
            manifest["frames"].append({
                "index": index, "scene": scene_id, "file": name,
                "sha256": hashlib.sha256(payload).hexdigest(),
            })
            local = index % per_sheet
            if local == 0:
                sheet = Image.new("RGB", (sheet_columns * thumbnail_width,
                                          sheet_rows * cell_height), "white")
            thumb = frame.resize((thumbnail_width, thumb_height), Image.Resampling.LANCZOS)
            x = local % sheet_columns * thumbnail_width
            y = local // sheet_columns * cell_height
            sheet.paste(thumb, (x, y))
            ImageDraw.Draw(sheet).text((x + 4, y + thumb_height + 3),
                                       f"#{index:06d} / scene {scene_id + 1}", fill="black")
            if local == per_sheet - 1 or index == plan.total_frames - 1:
                encoded_sheet = io.BytesIO()
                sheet.save(encoded_sheet, "PNG")
                archive.writestr(f"boards/board_{index // per_sheet:04d}.png",
                                 encoded_sheet.getvalue())
        archive.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
    return output.getvalue()
