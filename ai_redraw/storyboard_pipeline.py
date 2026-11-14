"""Single storyboard-first production entry point.

A real drawing renderer must be supplied. No fake animation, image wobble,
or placeholder frames are generated when inference is unavailable.
"""
from PIL import Image
from .storyboard_plan import plan_storyboard
from .drawing_generator import generate_drawings
from .storyboard_sheets import create_storyboard_archive
from .storyboard_verify import verify_storyboard_archive

def produce_storyboard(reference: Image.Image, story: str, renderer, *,
                       duration_seconds: float = 5.0, fps: int = 24,
                       width: int = 720, height: int = 1280,
                       max_mean_change: float = 100.0) -> tuple[bytes, dict]:
    plan = plan_storyboard(story, duration_seconds, fps, width, height)
    drawings = generate_drawings(plan, reference, renderer,
                                 max_mean_change=max_mean_change)
    archive = create_storyboard_archive(
        plan, lambda index, _instruction, _local: drawings[index])
    report = verify_storyboard_archive(archive)
    if not report["valid"] or report["unique_drawings"] != plan.total_frames:
        raise ValueError("Storyboard quality gate failed")
    return archive, report
