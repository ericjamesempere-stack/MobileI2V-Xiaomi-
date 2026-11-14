"""Storyboard sheet assembler. No synthetic frames or disguised image warps.

The drawing generator must supply a DISTINCT PNG for every planned frame.
The module validates size, count and source metadata before building contact
sheets and a lossless numbered-frame ZIP for later MP4 assembly.
"""
import io
import json
import zipfile
from collections.abc import Callable
from PIL import Image, ImageOps, ImageDraw
from .storyboard_plan import StoryboardPlan

def create_storyboard_archive(plan: StoryboardPlan,
                              draw_frame: Callable[[int, str, int], Image.Image],
                              sheet_columns: int = 4,
                              thumbnail_width: int = 180) -> bytes:
    if not 1 <= sheet_columns <= 12 or not 64 <= thumbnail_width <= 512:
        raise ValueError("Invalid contact sheet layout")
    if not 1 <= plan.total_frames <= 18000:
        raise ValueError("Invalid frame budget")
    sheet_rows = 4
    per_sheet = sheet_columns * sheet_rows
    cell_height = round(thumbnail_width * plan.height / plan.width) + 28
    thumb_height = cell_height - 28
    sheet = None
    manifest = {"fps": plan.fps, "width": plan.width, "height": plan.height,
                "total_frames": plan.total_frames,
                "scenes": [s.__dict__ for s in plan.scenes],
                "frames": []}
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=3) as archive:
        scene_id = 0
        for index in range(plan.total_frames):
            while scene_id + 1 < len(plan.scenes) and index >= plan.scenes[scene_id + 1].start_frame:
                scene_id += 1
            scene = plan.scenes[scene_id]
            frame = draw_frame(index, scene.instruction, index - scene.start_frame)
            if not isinstance(frame, Image.Image):
                raise ValueError(f"Drawing generator returned no image at frame {index}")
            if frame.size != (plan.width, plan.height):
                raise ValueError(f"Wrong proportions at frame {index}: {frame.size}")
            if frame.mode != "RGB":
                frame = frame.convert("RGB")
            frame_bytes = io.BytesIO()
            frame.save(frame_bytes, "PNG")
            name = f"frames/frame_{index:06d}.png"
            archive.writestr(name, frame_bytes.getvalue())
            manifest["frames"].append({"index": index, "scene": scene_id, "file": name})
            local = index % per_sheet
            if local == 0:
                sheet = Image.new("RGB", (sheet_columns * thumbnail_width, sheet_rows * cell_height), "white")
            thumbnail = ImageOps.fit(frame, (thumbnail_width, thumb_height))
            x = (local % sheet_columns) * thumbnail_width
            y = (local // sheet_columns) * cell_height
            sheet.paste(thumbnail, (x, y))
            ImageDraw.Draw(sheet).text((x + 4, y + thumb_height + 3), f"#{index:06d} / scene {scene_id + 1}", fill="black")
            if local == per_sheet - 1 or index == plan.total_frames - 1:
                buffer = io.BytesIO()
                sheet.save(buffer, "PNG")
                archive.writestr(f"boards/board_{index // per_sheet:04d}.png", buffer.getvalue())
        archive.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
    return output.getvalue()
