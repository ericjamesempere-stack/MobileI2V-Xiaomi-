#!/usr/bin/env python3
"""Karma One offline drawing renderer: distinct pose-based drawings, not photo warping.
Demonstration only: does NOT reconstruct a real person's likeness.
"""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

def joint_positions(index, count, action="walk", previous_action=None, blend=1.0, phase_index=None, proportions=None, width=360, height=480):
    """Return joints measured from the exact same geometry used to paint the frame."""
    _, joints = draw_pose(index, count, width=width, height=height, action=action,
                          previous_action=previous_action, blend=blend,
                          phase_index=phase_index, proportions=proportions,
                          return_joints=True)
    return joints

def draw_pose(index: int, count: int, width: int = 360, height: int = 480, appearance=None, action="walk", previous_action=None, blend=1.0, phase_index=None, face_image=None, proportions=None, return_joints=False):
    appearance = appearance or {}
    shirt_color = appearance.get("shirt", "#386eaa")
    pants_color = appearance.get("pants", "#25354b")
    skin_color = appearance.get("skin", "#b98766")
    hair_color = appearance.get("hair", "#332725")
    phase = 2 * math.pi * ((index if phase_index is None else phase_index) / 12.0)
    speeds = {"walk": 0.8, "run": 1.8, "dance": 1.2, "stand": 0.0, "crouch": 0.0, "fall": 0.0, "stumble": 0.5}
    if action not in speeds:
        raise ValueError(f"Unsupported action: {action}")
    target_speed = speeds[action]
    prior_speed = speeds.get(previous_action, target_speed)
    t = max(0.0, min(1.0, blend))
    smooth = t*t*t*(t*(6*t-15)+10)
    speed = prior_speed*(1-smooth) + target_speed*smooth
    step = math.sin(phase) * speed
    image = Image.new("RGB", (width, height), "#e7f0f4")
    pen = ImageDraw.Draw(image)
    proportions = proportions or {}
    def ratio(name, default):
        value = float(proportions.get(name, default))
        if not 0.5 <= value <= 1.5:
            raise ValueError(f"Invalid proportion {name}: {value}")
        return value
    leg_ratio = ratio("leg_length", 1.0)
    torso_ratio = ratio("torso_length", 1.0)
    arm_ratio = ratio("arm_length", 1.0)
    head_ratio = ratio("head_size", 1.0)
    cx, floor = width // 2, int(height * 0.86)
    # Two vertical impulses per stride: running has a stronger aerial phase.
    locomotion = max(0.0, min(1.0, speed / 1.8))
    bob = int(3 * abs(math.sin(phase)) + 7 * locomotion * max(0.0, math.cos(2*phase)))
    # Interpolate joint geometry, not just movement speed, across action boundaries.
    old_crouch = 1.0 if previous_action == "crouch" else 0.0
    new_crouch = 1.0 if action == "crouch" else 0.0
    crouch_amount = old_crouch*(1-smooth) + new_crouch*smooth if previous_action else new_crouch
    hip_height = 100 - 45*crouch_amount
    torso_height = 105 - 25*crouch_amount
    fall_levels = {"fall": 1.0, "stumble": 0.35}
    old_fall = fall_levels.get(previous_action, 0.0)
    new_fall = fall_levels.get(action, 0.0)
    fall_amount = old_fall*(1-smooth) + new_fall*smooth if previous_action else new_fall
    # Opposing pelvis sway helps transfer weight toward the support foot.
    sway = int(7 * locomotion * math.sin(phase))
    hip = (cx + sway + int(24*fall_amount), floor - int(hip_height*leg_ratio) - bob + int(48*fall_amount))
    shoulder = (cx + int(70*fall_amount), hip[1] - int(torso_height*torso_ratio*(1-fall_amount)) - int(18*fall_amount))
    head = (shoulder[0] + int(32*fall_amount), shoulder[1] - int(62*head_ratio*(1-fall_amount)) - int(10*fall_amount))
    pen.line((30, floor, width-30, floor), fill="#799ba0", width=3)
    # Each drawing is freshly rasterized from a new articulated pose.
    foot_spread = 28 + 27*crouch_amount
    # Opposite leg phases: stance foot remains planted while swing foot lifts.
    # Non-locomotion actions keep both feet on the ground.
    gait = max(0.0, min(1.0, speed / 1.8))
    left_lift = max(0.0, math.sin(phase)) * 16 * gait
    right_lift = max(0.0, -math.sin(phase)) * 16 * gait
    left_foot = (int(cx-foot_spread-27*step+10*fall_amount), floor-int(left_lift))
    right_foot = (int(cx+foot_spread+27*step+10*fall_amount), floor-int(right_lift))
    left_knee = (int((hip[0]+left_foot[0])/2-15-9*left_lift/16), min(floor,int((hip[1]+left_foot[1])/2-8*left_lift/16)))
    right_knee = (int((hip[0]+right_foot[0])/2+15+9*right_lift/16), min(floor,int((hip[1]+right_foot[1])/2-8*right_lift/16)))
    for knee, foot in [(left_knee,left_foot),(right_knee,right_foot)]:
        pen.line((hip,knee,foot), fill=pants_color, width=19, joint="curve")
        pen.ellipse((foot[0]-14,foot[1]-6,foot[0]+14,foot[1]+6),fill=pants_color)
    pen.line((hip,shoulder),fill=shirt_color,width=46)
    arm_joints = {}
    for direction in [-1,1]:
        hand=(int(cx+direction*(60*arm_ratio+20*step)+70*fall_amount),int(shoulder[1]+85*arm_ratio-direction*18*step+20*fall_amount))
        elbow=(int(cx+direction*42*arm_ratio+70*fall_amount),min(floor-6,int(shoulder[1]+40*arm_ratio+10*fall_amount)))
        hand=(hand[0],min(floor-9,hand[1]))
        side = "left" if direction == -1 else "right"
        arm_joints[side+"_elbow"] = elbow
        arm_joints[side+"_hand"] = hand
        pen.line((shoulder,elbow,hand),fill=shirt_color,width=15,joint="curve")
        pen.ellipse((hand[0]-9,hand[1]-9,hand[0]+9,hand[1]+9),fill=skin_color)
    pen.ellipse((head[0]-32,head[1]-42,head[0]+32,head[1]+42),fill=skin_color,outline="#483c37",width=3)
    if face_image is not None:
        face = face_image.convert("RGB").resize((60, 78), Image.Resampling.LANCZOS)
        mask = Image.new("L", face.size, 0)
        ImageDraw.Draw(mask).ellipse((1, 1, 58, 76), fill=255)
        image.paste(face, (head[0]-30, head[1]-39), mask)
    pen.pieslice((head[0]-34,head[1]-47,head[0]+34,head[1]+4),180,360,fill=hair_color)
    hair_style = appearance.get("hair_style", "short")
    if hair_style == "long":
        for offset in (-29, -20, 20, 29):
            pen.line((head[0]+offset,head[1]-27,head[0]+offset,head[1]+65), fill=hair_color, width=7)
    elif hair_style == "locs":
        for offset in (-31, -22, -13, 13, 22, 31):
            pen.line((head[0]+offset,head[1]-27,head[0]+offset + int(4*math.sin(phase)),head[1]+58), fill=hair_color, width=6)
    if face_image is None:
        for dx in (-12,12):
            pen.ellipse((head[0]+dx-3,head[1]-6,head[0]+dx+3,head[1]),fill="#20242c")
        pen.arc((head[0]-12,head[1]+8,head[0]+12,head[1]+23),0,180,fill="#51322d",width=2)
    if return_joints:
        return image, {"hip":hip, "shoulder":shoulder, "head":head,
                       "left_foot":left_foot, "right_foot":right_foot,
                       "left_knee":left_knee, "right_knee":right_knee,
                       **arm_joints}
    return image

def render(folder: Path, seconds: int, fps: int, appearance=None, action="walk"):
    if seconds < 1 or seconds > 300 or fps not in (24,30):
        raise ValueError("Duration 1..300 seconds; fps 24 or 30")
    folder.mkdir(parents=True,exist_ok=True)
    count=seconds*fps
    for i in range(count):
        draw_pose(i,count,appearance=appearance,action=action).save(folder / f"frame_{i:06d}.png")
    return count

if __name__ == "__main__":
    p=argparse.ArgumentParser()
    p.add_argument("folder",type=Path)
    p.add_argument("--seconds",type=int,default=3)
    p.add_argument("--fps",type=int,default=24)
    p.add_argument("--appearance", type=Path, help="Optional JSON character palette; manual, not photo extraction")
    p.add_argument("--action", choices=["walk", "run", "dance", "stand", "crouch", "fall", "stumble"], default="walk")
    args=p.parse_args()
    appearance=json.loads(args.appearance.read_text(encoding="utf-8")) if args.appearance else None
    print(f"Generated {render(args.folder,args.seconds,args.fps,appearance,args.action)} distinct pose drawings")
