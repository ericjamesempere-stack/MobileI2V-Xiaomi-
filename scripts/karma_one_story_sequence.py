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
    "stand": ("immobile", "debout", "attend", "stand", "stop", "se relève", "se releve", "se relever", "relève", "releve", "gets up", "get up", "stands up"),
    "crouch": ("accroupi", "accroupit", "accroupir", "crouch", "squat"),
    "fall": ("tombe", "tomber", "chute", "fall", "falls", "falling"),
    "stumble": ("trébuche", "trébucher", "trebuche", "trebucher", "perd l'équilibre", "stumble", "stumbles", "trip", "trips"),
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

def transition_blend(frame_offset, transition_frames, first_action=False):
    if first_action:
        return 1.0
    if transition_frames < 2:
        raise ValueError("Transition must span at least two frames")
    return max(0.0, min(1.0, frame_offset / (transition_frames - 1)))

def produce(story, output, seconds, fps=24, appearance=None, face_photo=None, face_box=None, color_regions=None, proportions=None, body_landmarks=None, detect_body=False):
    if seconds < 1 or seconds > 300 or fps not in (24,30):
        raise ValueError("Duration 1..300 seconds, fps 24 or 30")
    steps = plan(story)
    count = seconds * fps
    if count < len(steps) * 2:
        raise ValueError("Each action needs at least two frames for continuous transitions")
    face_image = None
    if face_photo is not None:
        if face_box is None:
            face_box = load("karma_one_face_detector").detect_face_box(face_photo)
        if len(face_box) != 4:
            raise ValueError("Face box must have four coordinates")
        l,t,r,b = face_box
        if not (0 <= l < r <= 1 and 0 <= t < b <= 1):
            raise ValueError("Face box must use normalized coordinates in 0..1")
        with Image.open(face_photo) as source:
            w,h = source.size
            face_image = source.convert("RGB").crop((int(l*w),int(t*h),max(int(l*w)+1,int(r*w)),max(int(t*h)+1,int(b*h))))
    if color_regions is not None:
        if face_photo is None:
            raise ValueError("Color regions require --face-photo")
        sampled = load("karma_one_photo_palette").extract(face_photo, color_regions)
        appearance = {**(appearance or {}), **sampled}
    if detect_body:
        if face_photo is None:
            raise ValueError("Automatic body detection requires --face-photo")
        if body_landmarks is not None:
            raise ValueError("Choose either automatic detection or manual body landmarks")
        body_landmarks = load("karma_one_pose_detector").detect(face_photo)
    if body_landmarks is not None:
        derived = load("karma_one_body_landmarks").derive(body_landmarks)
        proportions = {**derived, **(proportions or {})}
    drawing = load("karma_one_pose_drawings")
    assembler = load("karma_one_frame_assembler")
    frames_dir = output.parent / (output.stem + "_drawings")
    frames_dir.mkdir(parents=True, exist_ok=True)
    boundaries = []
    joint_samples = []
    transition_frames = max(2, round(fps * 0.25))
    for i, step in enumerate(steps):
        start = (i * count) // len(steps)
        end = ((i+1) * count) // len(steps)
        local_transition = min(transition_frames, end-start)
        boundaries.append({"action": step["action"], "start_frame": start, "end_frame_exclusive": end, "transition_frames": local_transition if i else 0})
        for frame in range(start, end):
            # Keep one consistent appearance across all actions.
            previous_action = steps[i-1]["action"] if i else None
            # First frame of a new action reproduces the preceding pose exactly.
            # Subsequent frames interpolate to the target with smoothstep in renderer.
            blend = transition_blend(frame-start, local_transition, first_action=(i == 0))
            joint_samples.append(drawing.joint_positions(frame-start,end-start,action=step["action"],
                                     previous_action=previous_action,blend=blend,phase_index=frame,
                                     proportions=proportions))
            image = drawing.draw_pose(frame-start, end-start, appearance=appearance,
                                      action=step["action"], previous_action=previous_action,
                                      blend=blend, phase_index=frame, face_image=face_image,
                                      proportions=proportions)
            image.save(frames_dir / f"frame_{frame:06d}.png")
    joint_report = load("karma_one_joint_quality").inspect(joint_samples)
    if joint_report["jump_count"]:
        raise ValueError("Joint continuity check failed: " + str(joint_report["jumps"][:3]))
    report = assembler.assemble(frames_dir, output, fps, count)
    report["joint_continuity"] = joint_report
    report["actions"] = boundaries
    report["transition_frames"] = transition_frames
    report["photo_identity_preserved"] = False
    report["reference_face_texture_used"] = face_image is not None
    report["reference_photo_palette_used"] = color_regions is not None
    report["custom_body_proportions_used"] = proportions is not None
    report["annotated_body_landmarks_used"] = body_landmarks is not None and not detect_body
    report["automatically_detected_body_landmarks_used"] = detect_body
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
    parser.add_argument("--color-regions", type=Path, help="JSON regions for skin, hair, shirt and pants sampled from same photo")
    parser.add_argument("--proportions", type=Path, help="Optional manual JSON body ratios; no automatic pose estimation")
    parser.add_argument("--body-landmarks", type=Path, help="Optional JSON manually annotated 2D joints")
    parser.add_argument("--detect-body", action="store_true", help="Optional MediaPipe pose detection from reference photo")
    parser.add_argument("--face-box", type=float, nargs=4, metavar=("LEFT","TOP","RIGHT","BOTTOM"), help="Optional manual normalized face crop; otherwise OpenCV detection")
    args = parser.parse_args()
    appearance = json.loads(args.appearance.read_text(encoding="utf-8")) if args.appearance else None
    color_regions = json.loads(args.color_regions.read_text(encoding="utf-8")) if args.color_regions else None
    proportions = json.loads(args.proportions.read_text(encoding="utf-8")) if args.proportions else None
    body_landmarks = json.loads(args.body_landmarks.read_text(encoding="utf-8")) if args.body_landmarks else None
    print(json.dumps(produce(args.story,args.output,args.seconds,args.fps,appearance,args.face_photo,args.face_box,color_regions,proportions,body_landmarks,args.detect_body),indent=2))
