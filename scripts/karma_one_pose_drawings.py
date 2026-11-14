#!/usr/bin/env python3
"""Karma One offline drawing renderer: distinct pose-based drawings, not photo warping.
Demonstration only: does NOT reconstruct a real person's likeness.
"""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

def draw_pose(index: int, count: int, width: int = 360, height: int = 480, appearance=None, action="walk"):
    appearance = appearance or {}
    shirt_color = appearance.get("shirt", "#386eaa")
    pants_color = appearance.get("pants", "#25354b")
    skin_color = appearance.get("skin", "#b98766")
    hair_color = appearance.get("hair", "#332725")
    phase = 2 * math.pi * (index / 12.0)
    speed = {"walk": 0.8, "run": 1.8, "dance": 1.2, "stand": 0.0}.get(action, 0.8)
    step = math.sin(phase) * speed
    image = Image.new("RGB", (width, height), "#e7f0f4")
    pen = ImageDraw.Draw(image)
    cx, floor = width // 2, int(height * 0.86)
    bob = int(5 * abs(math.sin(phase)))
    hip = (cx, floor - 100 - bob)
    shoulder = (cx, floor - 205 - bob)
    head = (cx, floor - 267 - bob)
    pen.line((30, floor, width-30, floor), fill="#799ba0", width=3)
    # Each drawing is freshly rasterized from a new articulated pose.
    left_foot = (int(cx-28-27*step), floor-int(13*max(0,step)))
    right_foot = (int(cx+28-27*step), floor-int(13*max(0,-step)))
    left_knee = (int((hip[0]+left_foot[0])/2-15), int((hip[1]+left_foot[1])/2))
    right_knee = (int((hip[0]+right_foot[0])/2+15), int((hip[1]+right_foot[1])/2))
    for knee, foot in [(left_knee,left_foot),(right_knee,right_foot)]:
        pen.line((hip,knee,foot), fill=pants_color, width=19, joint="curve")
        pen.ellipse((foot[0]-14,foot[1]-6,foot[0]+14,foot[1]+6),fill="#25354b")
    pen.line((hip,shoulder),fill=shirt_color,width=46)
    for direction in [-1,1]:
        hand=(int(cx+direction*(60+20*step)),int(shoulder[1]+85-direction*18*step))
        elbow=(int(cx+direction*42),int(shoulder[1]+40))
        pen.line((shoulder,elbow,hand),fill="#386eaa",width=15,joint="curve")
        pen.ellipse((hand[0]-9,hand[1]-9,hand[0]+9,hand[1]+9),fill=skin_color)
    pen.ellipse((head[0]-32,head[1]-42,head[0]+32,head[1]+42),fill="#b98766",outline="#483c37",width=3)
    pen.pieslice((head[0]-34,head[1]-47,head[0]+34,head[1]+4),180,360,fill=hair_color)
    hair_style = appearance.get("hair_style", "short")
    if hair_style == "long":
        for offset in (-29, -20, 20, 29):
            pen.line((head[0]+offset,head[1]-27,head[0]+offset,head[1]+65), fill=hair_color, width=7)
    elif hair_style == "locs":
        for offset in (-31, -22, -13, 13, 22, 31):
            pen.line((head[0]+offset,head[1]-27,head[0]+offset + int(4*math.sin(phase)),head[1]+58), fill=hair_color, width=6)
    for dx in (-12,12):
        pen.ellipse((head[0]+dx-3,head[1]-6,head[0]+dx+3,head[1]),fill="#20242c")
    pen.arc((head[0]-12,head[1]+8,head[0]+12,head[1]+23),0,180,fill="#51322d",width=2)
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
    p.add_argument("--action", choices=["walk", "run", "dance", "stand"], default="walk")
    args=p.parse_args()
    appearance=json.loads(args.appearance.read_text(encoding="utf-8")) if args.appearance else None
    print(f"Generated {render(args.folder,args.seconds,args.fps,appearance,args.action)} distinct pose drawings")
