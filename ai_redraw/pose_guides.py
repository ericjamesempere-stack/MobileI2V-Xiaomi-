"""Deterministic OpenPose-style pose guides for offline story actions.

Coordinates are approximate 2D stick figures. This is NOT pose estimation from
a reference photograph; it supplies explicit target skeletons for ControlNet.
"""
from PIL import Image, ImageDraw

LIMB_COLORS = [
    (255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0),
    (170, 255, 0), (85, 255, 0), (0, 255, 0), (0, 255, 85),
    (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255),
    (0, 0, 255), (85, 0, 255), (170, 0, 255), (255, 0, 255),
]
# 0 nose, 1 neck, 2/3/4 right arm, 5/6/7 left arm,
# 8/9/10 right leg, 11/12/13 left leg
EDGES = [(1, 2), (2, 3), (3, 4), (1, 5), (5, 6), (6, 7),
         (1, 8), (8, 9), (9, 10), (1, 11), (11, 12), (12, 13),
         (1, 0)]

def joints_for_action(action: str, phase: float = 0.0) -> dict[int, tuple[float, float]]:
    import math
    phase = max(0.0, min(1.0, phase))
    cycle = math.sin(phase * math.tau)
    points = {
        0: (.50, .17), 1: (.50, .28),
        2: (.42, .30), 3: (.36, .43), 4: (.33, .54),
        5: (.58, .30), 6: (.64, .43), 7: (.67, .54),
        8: (.46, .55), 9: (.43, .72), 10: (.42, .90),
        11: (.54, .55), 12: (.57, .72), 13: (.58, .90),
    }
    action = action.lower().strip()
    if action in ("run", "running", "course", "walk", "walking", "marche"):
        stride = .15 if action in ("run", "running", "course") else .08
        points[9] = (.43 + stride * cycle, .72)
        points[10] = (.42 + stride * cycle, .87 - .10 * max(0, cycle))
        points[12] = (.57 - stride * cycle, .72)
        points[13] = (.58 - stride * cycle, .87 - .10 * max(0, -cycle))
        points[4] = (.33 - stride * cycle, .52)
        points[7] = (.67 + stride * cycle, .52)
    elif action in ("jump", "jumping", "saut"):
        points[4] = (.26, .12)
        points[7] = (.74, .12)
        points[10] = (.33, .77)
        points[13] = (.67, .77)
    elif action in ("crouch", "crouching", "accroupi"):
        points[0] = (.50, .34)
        points[1] = (.50, .44)
        points[2], points[5] = (.42, .46), (.58, .46)
        points[3], points[6] = (.38, .58), (.62, .58)
        points[4], points[7] = (.45, .70), (.55, .70)
        points[8], points[11] = (.45, .68), (.55, .68)
        points[9], points[12] = (.33, .78), (.67, .78)
        points[10], points[13] = (.40, .90), (.60, .90)
    elif action in ("fall", "falling", "chute", "trebuche"):
        # Continuous rotation of body around pelvis to a grounded position.
        angle = phase * math.pi * .48
        hip_x, hip_y = .50, .74
        for index, (x, y) in points.items():
            dx, dy = x - .50, y - .55
            points[index] = (
                hip_x + dx * math.cos(angle) - dy * math.sin(angle),
                hip_y + dx * math.sin(angle) + dy * math.cos(angle),
            )
    elif action in ("rise", "standing_up", "releve"):
        return joints_for_action("chute", 1.0 - phase)
    elif action in ("wave", "salut"):
        points[6], points[7] = (.66, .20), (.70 + .04 * cycle, .10)
    return points

def render_pose(action: str, phase: float = 0.0, size: tuple[int, int] = (512, 512)) -> Image.Image:
    width, height = size
    if width < 64 or height < 64 or width > 2048 or height > 2048:
        raise ValueError("Invalid pose canvas")
    points = joints_for_action(action, phase)
    canvas = Image.new("RGB", size, (0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    def pixel(point):
        return (round(point[0] * width), round(point[1] * height))
    for i, (a, b) in enumerate(EDGES):
        draw.line((pixel(points[a]), pixel(points[b])),
                  fill=LIMB_COLORS[i % len(LIMB_COLORS)],
                  width=max(3, min(width, height) // 90))
    for index, point in points.items():
        x, y = pixel(point)
        radius = max(3, min(width, height) // 100)
        draw.ellipse((x-radius, y-radius, x+radius, y+radius),
                     fill=LIMB_COLORS[index % len(LIMB_COLORS)])
    return canvas
