"""Conservative frame quality gates for storyboard drawings.

Detects exact/near copies, extreme scene changes and aspect errors. It cannot
prove identity or narrative correctness; those require independent validation.
"""
from dataclasses import dataclass
from PIL import Image, ImageChops, ImageStat, ImageFilter


@dataclass(frozen=True)
class FrameQuality:
    mean_difference: float
    changed_pixel_fraction: float
    edge_difference: float
    identical: bool
    likely_static: bool
    abrupt_change: bool


def assess_pair(previous: Image.Image, current: Image.Image, *,
                sample_size: int = 128, static_threshold: float = 0.4,
                abrupt_threshold: float = 100.0) -> FrameQuality:
    if previous.size != current.size:
        raise ValueError("Frame dimensions differ")
    if not 32 <= sample_size <= 512:
        raise ValueError("Invalid sample size")
    a = previous.convert("RGB").resize((sample_size, sample_size), Image.Resampling.BILINEAR)
    b = current.convert("RGB").resize((sample_size, sample_size), Image.Resampling.BILINEAR)
    delta = ImageChops.difference(a, b)
    mean = sum(ImageStat.Stat(delta).mean) / 3
    mask = delta.convert("L").point(lambda v: 255 if v > 8 else 0)
    changed = ImageStat.Stat(mask).mean[0] / 255
    edges_a = a.convert("L").filter(ImageFilter.FIND_EDGES)
    edges_b = b.convert("L").filter(ImageFilter.FIND_EDGES)
    edges = ImageChops.difference(edges_a, edges_b)
    edge_mean = ImageStat.Stat(edges).mean[0]
    return FrameQuality(round(mean, 4), round(changed, 4), round(edge_mean, 4),
                        delta.getbbox() is None, mean < static_threshold,
                        mean > abrupt_threshold)
