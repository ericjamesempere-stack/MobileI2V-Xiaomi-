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
from PIL import Image

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

def produce(story, output, seconds, fps=24, appearance=None, face_photo=None, face_box=None):
    if seconds < 1 or seconds > 300 or fps not in (24,30):
        raise ValueError("Duration 1..300 seconds, fps 24 or 30")
    steps = plan(story)
    count = seconds * fps
    if count < len(steps):
        raise ValueError("More actions than available frames")
    face_image = None
    if face_photo is not None:
        if face_box is None or len(face_box) != 4:
            raise ValueError("A manually selected face box [left,top,right,bottom] is required")
        l,t,r,b = face_box
        if not (0 <= l < r <= 1 and 0 <= t < b <= 1):
            raise ValueError("Face box must use normalized coordinates in 0..1")
        with Image.open(face_photo) as source:
            w,h = source.size
            face_image = source.convert("RGB").crop((int(l*w),int(t*h),max(int(l*w)+1,int(r*w)),max(int(t*h)+1,int(b*h))))
    drawing = load("karma_one_pose_drawings")
    assembler = load("karma_one_frame_assembler")
    frames_dir = output.parent / (output.stem + "_drawings")
    frames_dir.mkdir(parents=True, exist_ok=True)
    boundaries = []
    transition_frames = max(1, round(fps * 0.25))
    for i, step in enumerate(steps):
        start = (i * count) // len(steps)
        end = ((i+1) * count) // len(steps)
        boundaries.append({"action": step["action"], "start_frame": start, "end_frame_exclusive": end})
        for frame in range(start, end):
            # Keep one consistent appearance across all actions.
            previous_action = steps[i-1]["action"] if i else None
            blend = min(1.0, (frame-start+1)/transition_frames)
            image = drawing.draw_pose(frame-start, end-start, appearance=appearance,
                                      action=step["action"], previous_action=previous_action,
                                      blend=blend, phase_index=frame, face_image=face_image)
            image.save(frames_dir / f"frame_{frame:06d}.png")
    report = assembler.assemble(frames_dir, output, fps, count)
    report["actions"] = boundaries
    report["transition_frames"] = transition_frames
    report["photo_identity_preserved"] = False
    report["reference_face_texture_used"] = face_image is not None
    output.with_suffix(".story.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--story", required=True)
    parser.add_argument("--seconds", type=int, default=4)
    parser.add_argument("--fps", type=int, choices=(24,30), default=24)
    parser.add_argument("--appearance", type=Path)
    parser.add_argument("--face-photo", type=Path, help="Reference photo with a visible face")
    parser.add_argument("--face-box", type=float, nargs=4, metavar=("LEFT","TOP","RIGHT","BOTTOM"), help="Manual normalized face crop")
    args = parser.parse_args()
    appearance = json.loads(args.appearance.read_text(encoding="utf-8")) if args.appearance else None
    print(json.dumps(produce(args.story,args.output,args.seconds,args.fps,appearance,args.face_photo,args.face_box),indent=2))
