#!/usr/bin/env python3
"""Karma One: simple offline story -> sequential pose drawings -> verified MP4.
Limited vocabulary; unknown instructions are rejected, never silently replaced.
Not photo-faithful animation.
"""
import argparse
import importlib.util
import json
import re
from pathlib import Path

ACTIONS = {
    "walk": ("marche", "marcher", "walk", "walking"),
    "run": ("court", "courir", "course", "run", "running"),
    "dance": ("danse", "danser", "dance", "dancing"),
    "stand": ("immobile", "debout", "attend", "stand", "stop"),
}

def load(name):
    path = Path(__file__).with_name(name + ".py")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def plan(story):
    segments = re.split(r"\b(?:puis|ensuite|et puis|then|and then)\b|[.;]", story.lower())
    result = []
    for segment in segments:
        segment = segment.strip()
        if not segment:
            continue
        matched = [action for action, words in ACTIONS.items()
                   if any(re.search(r"(?<!\w)" + re.escape(w) + r"(?!\w)", segment) for w in words)]
        if len(matched) != 1:
            raise ValueError(f"Ambiguous or unsupported movement: {segment!r}")
        result.append({"action": matched[0], "instruction": segment})
    if not result:
        raise ValueError("Empty story")
    return result

def produce(story, output, seconds, fps=24, appearance=None):
    if seconds < 1 or seconds > 300 or fps not in (24,30):
        raise ValueError("Duration 1..300 seconds, fps 24 or 30")
    steps = plan(story)
    count = seconds * fps
    if count < len(steps):
        raise ValueError("More actions than available frames")
    drawing = load("karma_one_pose_drawings")
    assembler = load("karma_one_frame_assembler")
    frames_dir = output.parent / (output.stem + "_drawings")
    frames_dir.mkdir(parents=True, exist_ok=True)
    boundaries = []
    for i, step in enumerate(steps):
        start = (i * count) // len(steps)
        end = ((i+1) * count) // len(steps)
        boundaries.append({"action": step["action"], "start_frame": start, "end_frame_exclusive": end})
        for frame in range(start, end):
            # Keep one consistent appearance across all actions.
            image = drawing.draw_pose(frame-start, end-start, appearance=appearance, action=step["action"])
            image.save(frames_dir / f"frame_{frame:06d}.png")
    report = assembler.assemble(frames_dir, output, fps, count)
    report["actions"] = boundaries
    report["photo_identity_preserved"] = False
    output.with_suffix(".story.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--story", required=True)
    parser.add_argument("--seconds", type=int, default=4)
    parser.add_argument("--fps", type=int, choices=(24,30), default=24)
    parser.add_argument("--appearance", type=Path)
    args = parser.parse_args()
    appearance = json.loads(args.appearance.read_text(encoding="utf-8")) if args.appearance else None
    print(json.dumps(produce(args.story,args.output,args.seconds,args.fps,appearance),indent=2))
