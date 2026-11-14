#!/usr/bin/env python3
"""Karma One offline end-to-end pose-drawing demonstration.
This is NOT a reference-photo character reconstruction or general text-to-motion model.
"""
import argparse
import importlib.util
import json
from pathlib import Path

def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def main():
    p = argparse.ArgumentParser()
    p.add_argument("output", type=Path)
    p.add_argument("--seconds", type=int, default=3)
    p.add_argument("--fps", type=int, choices=[24, 30], default=24)
    p.add_argument("--appearance", type=Path, help="Optional manual character palette JSON")
    p.add_argument("--photo", type=Path, help="Reference photo for color sampling")
    p.add_argument("--regions", type=Path, help="Manually marked normalized regions JSON")
    args = p.parse_args()
    drawing = load_module("karma_drawings", "karma_one_pose_drawings.py")
    assembly = load_module("karma_assembler", "karma_one_frame_assembler.py")
    folder = args.output.parent / (args.output.stem + "_drawings")
    appearance = json.loads(args.appearance.read_text(encoding="utf-8")) if args.appearance else None
    if args.photo or args.regions:
        if not (args.photo and args.regions):
            p.error("--photo and --regions must be provided together")
        sampler = load_module("karma_photo_palette", "karma_one_photo_palette.py")
        sampled = sampler.extract(args.photo, json.loads(args.regions.read_text(encoding="utf-8")))
        appearance = {**(appearance or {}), **sampled}
    total = drawing.render(folder, args.seconds, args.fps, appearance)
    result = assembly.assemble(folder, args.output, args.fps, total)
    result["generator"] = "offline_procedural_stylized_pose_drawings"
    result["photo_identity_preserved"] = False
    result["photo_palette_sampled"] = bool(args.photo)
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
