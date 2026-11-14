"""Storyboard-first production contract: image boards before MP4 encoding."""
from dataclasses import dataclass, asdict
from math import ceil
from typing import List

@dataclass(frozen=True)
class Scene:
    index: int
    instruction: str
    start_frame: int
    frame_count: int
    duration_seconds: float

@dataclass(frozen=True)
class StoryboardPlan:
    fps: int
    width: int
    height: int
    total_frames: int
    scenes: List[Scene]

    def as_dict(self):
        return asdict(self)

def plan_storyboard(story: str, duration_seconds: float = 5.0,
                    fps: int = 24, width: int = 720, height: int = 1280) -> StoryboardPlan:
    if not story or not story.strip() or len(story) > 10000:
        raise ValueError("Story must contain 1-10000 characters")
    if not 1 <= duration_seconds <= 300 or not 1 <= fps <= 60:
        raise ValueError("Duration or frame rate out of range")
    if not 64 <= width <= 4096 or not 64 <= height <= 4096:
        raise ValueError("Resolution out of range")
    # Sentence boundaries are initial scene candidates, not a restricted action vocabulary.
    import re
    chunks = [s.strip() for s in re.split(r"(?<=[.!?;])\s+|\n+", story.strip()) if s.strip()]
    if not chunks:
        chunks = [story.strip()]
    total = max(len(chunks), ceil(duration_seconds * fps))
    if len(chunks) > total:
        raise ValueError("Too many scenes for the selected duration")
    base, remainder = divmod(total, len(chunks))
    scenes = []
    cursor = 0
    for i, chunk in enumerate(chunks):
        count = base + (1 if i < remainder else 0)
        scenes.append(Scene(i, chunk, cursor, count, count / fps))
        cursor += count
    return StoryboardPlan(fps, width, height, total, scenes)
