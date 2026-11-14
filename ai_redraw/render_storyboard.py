"""CLI: create verified storyboard drawings with a real model provider.

Usage:
 python -m ai_redraw.render_storyboard --image reference.png --story "A bird flies." \
   --output story.zip --seconds 5 --fps 8 --style anime

Requires installed diffusers weights and sufficient GPU resources. No dummy
frames, no hidden still-image motion and no MP4 export before board validation.
"""
import argparse
import json
from pathlib import Path
from PIL import Image
from .model_storyboard_renderer import VideoModelStoryboardRenderer
from .storyboard_stream import produce_storyboard_to_file
from .storyboard_verify import verify_storyboard_archive

def main(argv=None):
    parser = argparse.ArgumentParser(description="Generate real storyboard drawings")
    parser.add_argument("--image", required=True)
    parser.add_argument("--story", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--seconds", type=float, default=5.0)
    parser.add_argument("--fps", type=int, default=8)
    parser.add_argument("--width", type=int, default=720)
    parser.add_argument("--height", type=int, default=1280)
    parser.add_argument("--style", choices=["manga", "bd", "cartoon", "anime", "natural", "cinema"], default="anime")
    parser.add_argument("--seed", type=int, default=1234)
    args = parser.parse_args(argv)
    if Path(args.image).resolve() == Path(args.output).resolve():
        parser.error("Input and output paths must differ")
    renderer = VideoModelStoryboardRenderer(style=args.style, seed=args.seed)
    with Image.open(args.image) as reference:
        report = produce_storyboard_to_file(
            reference, args.story, renderer, args.output,
            duration_seconds=args.seconds, fps=args.fps,
            width=args.width, height=args.height)
    # Reopen archive to verify each stored PNG before reporting success.
    verified = verify_storyboard_archive(Path(args.output).read_bytes())
    print(json.dumps({**report, **verified}, ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
