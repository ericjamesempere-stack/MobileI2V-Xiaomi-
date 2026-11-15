#!/usr/bin/env python3
"""Integration test for the desktop H264 encoder, using real PNG inputs."""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "tools"))
from encode_sequence import encode


@unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "FFmpeg/FFprobe required")
class TestEncoder(unittest.TestCase):
    def test_real_h264_video(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi",
                "-i", "testsrc2=size=128x128:rate=12:duration=1",
                "-frames:v", "12", "-start_number", "0",
                str(root / "frame_%06d.png"),
            ], check=True)
            (root / "manifest.json").write_text(json.dumps({
                "fps": 12, "frame_count": 12, "video_encoded": False
            }), encoding="utf-8")
            output = root / "output.mp4"
            encode(root, output)
            self.assertGreater(output.stat().st_size, 1000)
            probe = subprocess.check_output([
                "ffprobe", "-v", "error", "-select_streams", "v:0",
                "-show_entries", "stream=codec_name,nb_frames",
                "-of", "json", str(output)
            ], text=True)
            stream = json.loads(probe)["streams"][0]
            self.assertEqual(stream["codec_name"], "h264")
            self.assertEqual(int(stream["nb_frames"]), 12)

    def test_missing_frames_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "manifest.json").write_text(json.dumps({
                "fps": 12, "frame_count": 2, "video_encoded": False
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Missing frame"):
                encode(root, root / "output.mp4")
            self.assertFalse((root / "output.mp4").exists())


if __name__ == "__main__":
    unittest.main()
