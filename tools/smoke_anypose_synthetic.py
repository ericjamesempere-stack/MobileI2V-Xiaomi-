"""One-shot public AnyPose inference smoke test with synthetic stick-figure inputs.

No personal photos or user images are read. The public service may refuse
requests, queue indefinitely, or require login; failure is reported honestly.
"""
import json
import os
import shutil
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw


def make_figure(path, *, arms_up=False):
    image = Image.new("RGB", (256, 256), "#f0ede8")
    draw = ImageDraw.Draw(image)
    draw.ellipse((103, 30, 153, 80), fill="#b47c56", outline="#40362f", width=3)
    draw.line((128, 80, 128, 170), fill="#1e5b90", width=19)
    if arms_up:
        draw.line((128, 102, 65, 48), fill="#b47c56", width=12)
        draw.line((128, 102, 192, 48), fill="#b47c56", width=12)
    else:
        draw.line((128, 102, 75, 156), fill="#b47c56", width=12)
        draw.line((128, 102, 181, 156), fill="#b47c56", width=12)
    draw.line((128, 170, 92, 239), fill="#263447", width=16)
    draw.line((128, 170, 165, 239), fill="#263447", width=16)
    image.save(path)


def main():
    from gradio_client import Client, handle_file
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        reference = root / "reference.png"
        pose = root / "pose.png"
        make_figure(reference)
        make_figure(pose, arms_up=True)
        artifact_dir = Path(os.environ.get("MOBILEI2V_TEST_ARTIFACTS", "/tmp/mobilei2v_anypose_artifacts"))
        artifact_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(reference, artifact_dir / "reference.png")
        shutil.copy2(pose, artifact_dir / "pose.png")
        client = Client("abidlabs/Qwen-Image-Edit-2511-AnyPose", verbose=False)
        job = client.submit(
            handle_file(str(reference)), handle_file(str(pose)),
            "Make the character in image 1 raise both arms overhead as in image 2. Keep the same clothing, face, and background.",
            0, False, 1.0, 4, 256, 256, False, api_name="/infer"
        )
        # GitHub job enforces an outer timeout. The inner call can be cancelled
        # by stopping the workflow if the free queue stalls.
        result = job.result(timeout=150)
        gallery = result[0] if isinstance(result, (list, tuple)) else result
        from backend.anypose_bridge import first_gallery_path
        path = first_gallery_path(gallery)
        if not path or not Path(path).is_file():
            raise RuntimeError("AnyPose returned no local image")
        with Image.open(path) as output:
            output.verify()
        shutil.copy2(path, artifact_dir / "generated.png")
        print(json.dumps({"remote_inference": "success", "output_image": "verified", "privacy": "synthetic inputs only"}))


if __name__ == "__main__":
    main()
