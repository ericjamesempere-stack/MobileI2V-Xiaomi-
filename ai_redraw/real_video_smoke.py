#!/usr/bin/env python3
"""Private real-inference storyboard-to-MP4 smoke test.

Usage (on a GPU-equipped machine with the real model installed):
 python -m ai_redraw.real_video_smoke --reference /private/character.png --output /private/test.mp4

Never uploads the reference or frames to GitHub. No synthetic fallback.
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
from .pose import pose_redraw
from .pose_guides import render_pose


def run(reference_path: Path, output_path: Path, action: str, drawings: int, fps: int):
    if not reference_path.is_file():
        raise FileNotFoundError(f"Private image missing: {reference_path}")
    if drawings < 2 or drawings > 120 or fps < 1 or fps > 60:
        raise ValueError("drawings must be 2..120 and fps 1..60")
    reference = Image.open(reference_path).convert("RGB")
    if min(reference.size) < 32:
        raise ValueError("Reference image too small")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="private_cartoon_") as folder:
        frames = Path(folder)
        sizes = []
        changes = []
        previous = None
        for i in range(drawings):
            phase = i / max(1, drawings - 1)
            pose = render_pose(action, phase)
            # Real inference. Raises if model weights/GPU are missing.
            frame = pose_redraw(reference, pose,
                                f"Same recognizable character and clothes, full body, {action}",
                                0.55, 1234 + i).convert("RGB")
            if previous is not None:
                if frame.size != previous.size:
                    raise RuntimeError("Generated images have inconsistent dimensions")
                diff = ImageChops.difference(frame, previous)
                changes.append(sum(ImageStat.Stat(diff).mean) / 3.0)
            sizes.append(frame.size)
            frame.save(frames / f"frame_{i:04d}.png")
            previous = frame
        if max(changes, default=0) < 0.5:
            raise RuntimeError("All drawings nearly identical: real animation not demonstrated")
        # Frames are genuine distinct redraws. MP4 frame rate equals drawing rate;
        # no artificial claim of 30 unique drawings/s.
        cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
               "-framerate", str(fps), "-i", str(frames / "frame_%04d.png"),
               "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
               str(output_path)]
        subprocess.run(cmd, check=True, timeout=180)
    probe = subprocess.run(["ffprobe", "-v", "error", "-count_frames",
                            "-select_streams", "v:0",
                            "-show_entries", "stream=nb_read_frames,width,height,r_frame_rate,duration",
                            "-of", "json", str(output_path)],
                           capture_output=True, text=True, check=True, timeout=60)
    stream = json.loads(probe.stdout)["streams"][0]
    counted = int(stream.get("nb_read_frames", -1))
    if counted != drawings:
        raise RuntimeError(f"MP4 frame mismatch: {counted} != {drawings}")
    # Full video decoding is required, not just a valid MP4 container.
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(output_path),
                    "-f", "null", "-"], check=True, timeout=180)
    duration = float(stream.get("duration", drawings / fps))
    if abs(duration - drawings / fps) > 0.15:
        raise RuntimeError(f"Unexpected duration: {duration}")
    return {"ok": True, "video": str(output_path), "frames": counted,
            "fps": fps, "duration_seconds": duration, "size": sizes[0],
            "mean_interframe_difference": sum(changes) / len(changes),
            "identity_verified": False, "model": "ControlNet OpenPose img2img"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--action", default="marche")
    parser.add_argument("--drawings", type=int, default=6)
    parser.add_argument("--fps", type=int, default=6)
    args = parser.parse_args()
    print(json.dumps(run(args.reference, args.output, args.action,
                         args.drawings, args.fps), indent=2))


if __name__ == "__main__":
    main()
