"""Reference-anchored sequential drawing generator for arbitrary subjects.

This module does not pretend to provide a generative model. A configured
renderer must redraw the original reference for each requested frame.
Original reference is supplied on EVERY call to reduce subject/style drift.
The previous accepted frame is also supplied to improve temporal continuity.
All produced drawings are checked for resolution and gross visual drift.
"""
from dataclasses import dataclass
from collections.abc import Callable
from PIL import Image, ImageChops, ImageStat
from .storyboard_plan import StoryboardPlan

@dataclass(frozen=True)
class FrameRequest:
    frame_index: int
    scene_index: int
    scene_instruction: str
    phase: float
    fps: int
    width: int
    height: int
    reference: Image.Image
    previous: Image.Image | None

Renderer = Callable[[FrameRequest], Image.Image]

def generate_drawings(plan: StoryboardPlan, reference: Image.Image,
                      renderer: Renderer, *, max_mean_change: float = 100.0,
                      reject_duplicates: bool = True) -> list[Image.Image]:
    if not isinstance(reference, Image.Image):
        raise ValueError("Reference image is required")
    if not 0 < max_mean_change <= 255:
        raise ValueError("Invalid continuity threshold")
    if not 1 <= plan.total_frames <= 18000:
        raise ValueError("Invalid frame count")
    original = reference.convert("RGB").copy()
    drawings = []
    scene_index = 0
    for index in range(plan.total_frames):
        while (scene_index + 1 < len(plan.scenes) and
               index >= plan.scenes[scene_index + 1].start_frame):
            scene_index += 1
        scene = plan.scenes[scene_index]
        request = FrameRequest(
            index, scene_index, scene.instruction,
            (index - scene.start_frame) / max(1, scene.frame_count - 1),
            plan.fps, plan.width, plan.height,
            original.copy(), drawings[-1].copy() if drawings else None)
        image = renderer(request)
        if not isinstance(image, Image.Image):
            raise ValueError(f"Renderer failed at frame {index}")
        if image.size != (plan.width, plan.height):
            raise ValueError(f"Incorrect drawing size at frame {index}: {image.size}")
        image = image.convert("RGB")
        if drawings:
            small_a = drawings[-1].resize((64, 64))
            small_b = image.resize((64, 64))
            delta = ImageChops.difference(small_a, small_b)
            change = sum(ImageStat.Stat(delta).mean) / 3
            if reject_duplicates and delta.getbbox() is None:
                raise ValueError(f"Duplicate drawing at frame {index}")
            if change > max_mean_change:
                raise ValueError(f"Visual discontinuity at frame {index}: {change:.2f}")
        drawings.append(image.copy())
    return drawings
