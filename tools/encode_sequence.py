#!/usr/bin/env python3
"""Encode a MobileI2V numbered PNG sequence as a real H.264 MP4.

Desktop/CI tool. Android requires MediaCodec integration separately.
Usage: python3 tools/encode_sequence.py path/to/sequence [output.mp4]
"""
import json
import pathlib
import shutil
import subprocess
import sys


def encode(directory: pathlib.Path, destination: pathlib.Path) -> None:
    manifest_path = directory / "manifest.json"
    if not manifest_path.is_file():
        raise ValueError("Missing manifest.json")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    fps = int(manifest["fps"])
    count = int(manifest["frame_count"])
    if not 1 <= fps <= 60 or not 1 <= count <= 18000:
        raise ValueError("Invalid fps or frame count")
    if manifest.get("video_encoded") is not False:
        raise ValueError("Expected an unencoded PNG sequence")
    for i in range(count):
        if not (directory / f"frame_{i:06d}.png").is_file():
            raise ValueError(f"Missing frame {i}")
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg not installed")
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-framerate", str(fps), "-start_number", "0",
        "-i", str(directory / "frame_%06d.png"),
        "-frames:v", str(count), "-an", "-c:v", "libx264",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        str(destination),
    ]
    subprocess.run(command, check=True)
    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError("MP4 encoding did not produce a file")


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        raise SystemExit("Usage: encode_sequence.py sequence_dir [output.mp4]")
    folder = pathlib.Path(sys.argv[1]).resolve()
    output = pathlib.Path(sys.argv[2]).resolve() if len(sys.argv) == 3 else folder / "animation.mp4"
    encode(folder, output)
    print(f"MP4_OK {output}")
