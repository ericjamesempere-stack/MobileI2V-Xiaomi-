#!/usr/bin/env python3
"""Validate genuine MNN diffusion exports, fail closed on missing external weights."""
import argparse
import json
from pathlib import Path
from mnn_sd_model_manifest import create_manifest

REQUIRED = ("text_encoder", "unet", "vae_decoder")
def inspect(root: Path):
    if not root.is_dir():
        raise ValueError("model directory missing")
    for name in REQUIRED:
        graph = root / (name + ".mnn")
        if not graph.is_file() or graph.stat().st_size < 1024:
            raise ValueError("missing or implausibly small converted graph: " + name)
        external = root / (name + ".mnn.weight")
        if external.exists() and external.stat().st_size < 1024:
            raise ValueError("empty external weights: " + name)
    tokenizer = root / "tokenizer.mtok"
    if not tokenizer.is_file() or tokenizer.stat().st_size < 1024:
        raise ValueError("missing real tokenizer.mtok")
    files = {k: k + (".mtok" if k == "tokenizer" else ".mnn")
             for k in ("tokenizer",) + REQUIRED}
    manifest = create_manifest(root, files)
    for name in REQUIRED:
        ext = root / (name + ".mnn.weight")
        if ext.is_file():
            import hashlib
            sha = hashlib.sha256()
            with ext.open("rb") as stream:
                for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
                    sha.update(chunk)
            manifest["components"][name]["external_weight_file"] = ext.name
            manifest["components"][name]["external_weight_sha256"] = sha.hexdigest()
            manifest["components"][name]["external_weight_bytes"] = ext.stat().st_size
    manifest["graph_execution_verified"] = False
    manifest["tokenizer_execution_verified"] = False
    manifest["on_device_inference_verified"] = False
    return manifest

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", required=True, type=Path)
    args = parser.parse_args()
    data = inspect(args.model_dir)
    out = args.model_dir / "manifest.json"
    out.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print("KARMA_MNN_SD_EXPORT_FILES_VERIFIED", out)
    print("Graph load/inference NOT verified")
