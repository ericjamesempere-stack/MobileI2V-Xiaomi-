#!/usr/bin/env python3
"""Karma One: assemble individually generated drawings, never warp a still photo.
Input: numbered PNG drawings frame_000000.png ... frame_NNNNNN.png.
Requires Pillow and ffmpeg/ffprobe. No paid API.
"""
import argparse
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

def run(cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout

def assemble(folder: Path, output: Path, fps: int, expected: int | None = None):
    if not 1 <= fps <= 60:
        raise ValueError("fps must be 1..60")
    frames = sorted(folder.glob("frame_*.png"))
    if not frames:
        raise ValueError("No generated drawings found")
    if expected is not None and len(frames) != expected:
        raise ValueError(f"Expected {expected} drawings, got {len(frames)}")
    report = {"frame_count": len(frames), "fps": fps,
              "duration_seconds": len(frames) / fps, "warnings": []}
    prev = None
    for i, path in enumerate(frames):
        if path.name != f"frame_{i:06d}.png":
            raise ValueError(f"Missing/out-of-order drawing at {i}: {path.name}")
        with Image.open(path) as loaded:
            frame = loaded.convert("RGB")
        if prev is None:
            report["resolution"] = list(frame.size)
        elif frame.size != prev.size:
            raise ValueError(f"Resolution mismatch at frame {i}")
        if prev is not None:
            difference = ImageChops.difference(frame, prev)
            mean = sum(ImageStat.Stat(difference).mean) / 3
            if mean < 0.05:
                report["warnings"].append({"frame": i, "issue": "near_duplicate"})
            if mean > 45:
                report["warnings"].append({"frame": i, "issue": "large_visual_jump"})
        prev = frame
    report["warning_count"] = len(report["warnings"])
    output.parent.mkdir(parents=True, exist_ok=True)
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
         "-framerate", str(fps), "-start_number", "0",
         "-i", str(folder / "frame_%06d.png"),
         "-c:v", "libx264", "-pix_fmt", "yuv420p",
         "-movflags", "+faststart", str(output)])
    probed = json.loads(run(["ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=nb_frames,width,height",
        "-of", "json", str(output)]))
    actual = int(probed["streams"][0]["nb_frames"])
    if actual != len(frames):
        output.unlink(missing_ok=True)
        raise RuntimeError(f"MP4 frame count mismatch: {actual} != {len(frames)}")
    report["output"] = str(output)
    report["mp4_verified"] = True
    output.with_suffix(".report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--expected", type=int)
    args = parser.parse_args()
    print(json.dumps(assemble(args.frames, args.output, args.fps, args.expected),
                     ensure_ascii=False, indent=2))
