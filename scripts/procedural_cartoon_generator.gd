extends RefCounted
# Real, fully offline procedural cartoon drawing from text.
# Not a diffusion model: produces a stylized character sheet, not arbitrary
# photorealistic or reference-faithful illustrations.
func render(description: String, phase: float = 0.0, size: Vector2i = Vector2i(360, 480), action: String = "danse") -> Image:
    var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    var sky := Color("#d9e9f1")
    image.fill(sky)
    var seed: int = absi(description.to_lower().hash())
    var skin := Color("#d8a27b")
    var shirt := Color("#306caa") if seed % 2 == 0 else Color("#c34e59")
    var pants := Color("#25354b")
    var hair := Color("#342b2b")
    var scale: float = float(size.x) / 360.0
    var cx: float = size.x * 0.5
    var floor_y: float = size.y * 0.85
    _ellipse(image, Vector2(cx, floor_y + 5 * scale), Vector2(85, 12) * scale, Color("#a8c6cf"))
    var swing: float = sin(phase * TAU)
    var lift: float = absf(sin(phase * TAU)) * 6.0 * scale
    if action == "repos":
        swing = 0.0
        lift = 0.0
    elif action == "marche":
        swing *= 0.45
        lift *= 0.4
    elif action == "course":
        swing *= 1.6
        lift *= 1.8
    elif action == "saut":
        lift = (10.0 + 58.0 * absf(sin(phase * PI))) * scale
        swing *= 0.25
    elif action == "chute" or action == "trebuche":
        lift = -minf(1.0, phase) * 42.0 * scale
        swing = minf(1.0, phase) * 1.4
    elif action == "releve":
        lift = -(1.0 - minf(1.0, phase)) * 42.0 * scale
        swing = (1.0 - minf(1.0, phase)) * 1.4
    # At the start of a fall, the body leans forward before reaching the
    # ground. The same curve runs backward when the character stands up.
    var balance_progress: float = 0.0
    if action == "chute" or action == "trebuche":
        balance_progress = clampf(phase, 0.0, 1.0)
    elif action == "releve":
        balance_progress = 1.0 - clampf(phase, 0.0, 1.0)
    var lean: float = sin(balance_progress * PI) * 32.0 * scale
    var hip := Vector2(cx, floor_y - 104 * scale - lift)
    var shoulder := Vector2(cx, floor_y - 210 * scale - lift)
    shoulder.x += lean
    # A fall must actually rotate the torso toward the ground.
    # Previously only vertical offsets changed: the figure remained standing.
    var fall_progress: float = 0.0
    if action == "chute" or action == "trebuche":
        fall_progress = clampf(phase, 0.0, 1.0)
    elif action == "releve":
        fall_progress = 1.0 - clampf(phase, 0.0, 1.0)
    var fallen_hip := Vector2(cx - 34.0 * scale, floor_y - 35.0 * scale)
    var fallen_shoulder := Vector2(cx + 92.0 * scale, floor_y - 38.0 * scale)
    hip = hip.lerp(fallen_hip, fall_progress)
    shoulder = shoulder.lerp(fallen_shoulder, fall_progress)
    # The feet must participate in the fall instead of staying in the
    # original standing position. This also makes the reverse rise coherent.
    var left_foot := Vector2(cx - (30 + 18 * swing) * scale, floor_y - maxf(0.0, swing) * 18 * scale)
    var right_foot := Vector2(cx + (30 - 18 * swing) * scale, floor_y - maxf(0.0, -swing) * 18 * scale)
    left_foot = left_foot.lerp(Vector2(cx - 118.0 * scale, floor_y - 9.0 * scale), fall_progress)
    right_foot = right_foot.lerp(Vector2(cx - 70.0 * scale, floor_y - 9.0 * scale), fall_progress)
    # A run is not merely a waving torso: move knees and feet in opposite
    # phases and visibly lift the swinging leg off the ground.
    if action == "course" or action == "marche":
        var stride_length: float = 47.0 if action == "course" else 23.0
        var foot_lift: float = 42.0 if action == "course" else 15.0
        var cycle: float = phase * TAU
        left_foot = Vector2(cx - 18.0 * scale + sin(cycle) * stride_length * scale,
            floor_y - maxf(0.0, cos(cycle)) * foot_lift * scale)
        right_foot = Vector2(cx + 18.0 * scale - sin(cycle) * stride_length * scale,
            floor_y - maxf(0.0, -cos(cycle)) * foot_lift * scale)
    var left_knee := hip.lerp(left_foot, 0.52) + Vector2(-12 * scale, -12 * scale)
    var right_knee := hip.lerp(right_foot, 0.52) + Vector2(12 * scale, -12 * scale)
    _stroke(image, hip + Vector2(-13, 0) * scale, left_knee, 19 * scale, pants)
    _stroke(image, left_knee, left_foot, 17 * scale, pants)
    _stroke(image, hip + Vector2(13, 0) * scale, right_knee, 19 * scale, pants)
    _stroke(image, right_knee, right_foot, 17 * scale, pants)
    _ellipse(image, left_foot + Vector2(-6, 0) * scale, Vector2(22, 9) * scale, Color("#172533"))
    _ellipse(image, right_foot + Vector2(6, 0) * scale, Vector2(22, 9) * scale, Color("#172533"))
    _stroke(image, hip, shoulder, 57 * scale, shirt)
    var left_hand := shoulder + Vector2((-67 - 17 * swing) * scale, (67 + 28 * swing) * scale)
    var right_hand := shoulder + Vector2((67 - 17 * swing) * scale, (67 - 28 * swing) * scale)
    # During a fall, put both hands near the ground to support the body.
    # During a stand-up, reverse those joint positions continuously.
    left_hand = left_hand.lerp(Vector2(cx + 12 * scale, floor_y - 12 * scale), fall_progress)
    right_hand = right_hand.lerp(Vector2(cx + 114 * scale, floor_y - 12 * scale), fall_progress)
    if action == "salut":
        right_hand = shoulder + Vector2(63 * scale, (-68 + 12 * swing) * scale)
    elif action == "saut":
        left_hand = shoulder + Vector2(-65 * scale, -65 * scale)
        right_hand = shoulder + Vector2(65 * scale, -65 * scale)
    # Two-segment arms: elbow bends independently during a run and while
    # bracing for a fall. A single straight shoulder-to-hand line cannot
    # communicate these gestures.
    var left_root: Vector2 = shoulder + Vector2(-22, 3) * scale
    var right_root: Vector2 = shoulder + Vector2(22, 3) * scale
    var left_elbow: Vector2 = left_root.lerp(left_hand, 0.48) + Vector2((-15 - 8 * swing) * scale, (-9 + 8 * swing) * scale)
    var right_elbow: Vector2 = right_root.lerp(right_hand, 0.48) + Vector2((15 - 8 * swing) * scale, (-9 - 8 * swing) * scale)
    left_elbow = left_elbow.lerp(left_root.lerp(left_hand, 0.5) + Vector2(-8, -15) * scale, fall_progress)
    right_elbow = right_elbow.lerp(right_root.lerp(right_hand, 0.5) + Vector2(8, -15) * scale, fall_progress)
    _stroke(image, left_root, left_elbow, 18 * scale, shirt)
    _stroke(image, left_elbow, left_hand, 15 * scale, shirt)
    _stroke(image, right_root, right_elbow, 18 * scale, shirt)
    _stroke(image, right_elbow, right_hand, 15 * scale, shirt)
    _ellipse(image, left_hand, Vector2(10, 10) * scale, skin)
    _ellipse(image, right_hand, Vector2(10, 10) * scale, skin)
    # Head follows the torso rotation instead of floating above it.
    var head := shoulder + Vector2(0, -60 * scale).lerp(Vector2(49 * scale, -3 * scale), fall_progress)
    _ellipse(image, head, Vector2(33, 43) * scale, skin)
    _ellipse(image, head + Vector2(0, -29) * scale, Vector2(35, 17) * scale, hair)
    for side in [-1, 1]:
        _ellipse(image, head + Vector2(side * 13, -4) * scale, Vector2(4, 5) * scale, Color("#ffffff"))
        _ellipse(image, head + Vector2(side * 13, -4) * scale, Vector2(2, 3) * scale, Color("#192c35"))
    _stroke(image, head + Vector2(-8, 18) * scale, head + Vector2(8, 18) * scale, 2 * scale, Color("#703c3b"))
    return image

func _ellipse(img: Image, center: Vector2, radius: Vector2, color: Color) -> void:
    var rx: float = maxf(1.0, radius.x)
    var ry: float = maxf(1.0, radius.y)
    for y in range(maxi(0, floori(center.y - ry)), mini(img.get_height(), ceili(center.y + ry + 1))):
        for x in range(maxi(0, floori(center.x - rx)), mini(img.get_width(), ceili(center.x + rx + 1))):
            var dx: float = (x - center.x) / rx
            var dy: float = (y - center.y) / ry
            if dx * dx + dy * dy <= 1.0:
                img.set_pixel(x, y, color)

func _stroke(img: Image, a: Vector2, b: Vector2, thickness: float, color: Color) -> void:
    var length: int = maxi(1, ceili(a.distance_to(b)))
    for i in range(length + 1):
        _ellipse(img, a.lerp(b, float(i) / length), Vector2.ONE * maxf(1.0, thickness * 0.5), color)
