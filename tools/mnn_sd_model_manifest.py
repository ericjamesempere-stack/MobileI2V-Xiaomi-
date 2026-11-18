#!/usr/bin/env python3
"""Create a verified local MNN Stable Diffusion model manifest. No fake weights.

Usage:
 python3 tools/mnn_sd_model_manifest.py --model-dir /path/to/converted/mnn/sd15
Files must be genuine converted MNN graphs/tokenizer assets; no network access.
"""
import argparse
import hashlib
import json
from pathlib import Path

REQUIRED = ("tokenizer", "text_encoder", "unet", "vae_decoder")
MAX_FILE = 8 * 1024**3

def create_manifest(directory: Path, filenames: dict[str, str]) -> dict:
    if not directory.is_dir():
        raise ValueError("model directory missing")
    components = {}
    for key in REQUIRED:
        name = filenames[key]
        if not name or name != Path(name).name or name.startswith(".") or "\\" in name:
            raise ValueError(f"unsafe filename for {key}")
        path = directory / name
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"missing or linked component: {key}")
        size = path.stat().st_size
        if size <= 0 or size > MAX_FILE:
            raise ValueError(f"invalid component size: {key}")
        sha = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
                sha.update(chunk)
        components[key] = {"file": name, "sha256": sha.hexdigest(), "bytes": size}
    return {
        "format": "karma-mnn-sd15-components-v1",
        "components": components,
        "weights_verified": False,
        "note": "SHA256 manifest only; graph compatibility and image inference are NOT validated",
    }

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", required=True, type=Path)
    for key in REQUIRED:
        parser.add_argument("--" + key.replace("_", "-"), default=key + (".json" if key == "tokenizer" else ".mnn"))
    args = parser.parse_args()
    names = {key: getattr(args, key) for key in REQUIRED}
    manifest = create_manifest(args.model_dir, names)
    output = args.model_dir / "manifest.json"
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Model manifest created: {output} (model execution NOT verified)")

if __name__ == "__main__":
    main()
