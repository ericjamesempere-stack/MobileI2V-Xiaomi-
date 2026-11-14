extends RefCounted
# Procedural articulated preview: independent body layers, two-bone IK
# and joint circles. Unlike rotating cutout rectangles, this renderer
# never copies background or neighboring body parts into moving limbs.

var ik = preload("res://scripts/two_bone_ik.gd").new()

func _capsule(image: Image, start: Vector2, finish: Vector2, radius: float, color: Color) -> void:
    var x0 := maxi(0, floori(minf(start.x, finish.x) - radius - 2.0))
    var x1 := mini(image.get_width() - 1, ceili(maxf(start.x, finish.x) + radius + 2.0))
    var y0 := maxi(0, floori(minf(start.y, finish.y) - radius - 2.0))
    var y1 := mini(image.get_height() - 1, ceili(maxf(start.y, finish.y) + radius + 2.0))
    var axis := finish - start
    var length_sq := maxf(axis.length_squared(), 0.001)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            var point := Vector2(float(x), float(y))
            var t := clampf((point - start).dot(axis) / length_sq, 0.0, 1.0)
            var distance := point.distance_to(start + axis * t)
            var alpha := clampf(radius + 0.5 - distance, 0.0, 1.0)
            if alpha > 0.0:
                image.set_pixel(x, y, image.get_pixel(x, y).lerp(color, alpha))

func draw_frame(width: int, height: int, time: float) -> Image:
    var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
    image.fill(Color("25364a"))
    var scale := minf(float(width) / 360.0, float(height) / 480.0)
    var center := Vector2(width * 0.5, height * 0.49)
    var cycle := time * TAU * 1.2
    var bounce := 5.0 * absf(sin(cycle))
    var sway := 7.0 * sin(cycle * 0.5)
    var hip := center + Vector2(sway, 50.0 - bounce) * scale
    var chest := hip + Vector2(-sway * 0.4, -111.0) * scale
    var left_shoulder := chest + Vector2(-29, -1) * scale
    var right_shoulder := chest + Vector2(29, -1) * scale
    var left_hip := hip + Vector2(-17, 0) * scale
    var right_hip := hip + Vector2(17, 0) * scale
    var foot_y := float(height) * 0.88
    var left_foot := Vector2(center.x - 24.0 * scale + 20.0 * sin(cycle) * scale, foot_y - 14.0 * maxf(0.0, sin(cycle)) * scale)
    var right_foot := Vector2(center.x + 24.0 * scale - 20.0 * sin(cycle) * scale, foot_y - 14.0 * maxf(0.0, -sin(cycle)) * scale)
    var left_hand := left_shoulder + Vector2(-47.0 + 13.0 * sin(cycle), 79.0 + 19.0 * sin(cycle)) * scale
    var right_hand := right_shoulder + Vector2(47.0 + 13.0 * sin(cycle), 79.0 - 19.0 * sin(cycle)) * scale
    var left_leg: Dictionary = ik.solve_two_bone(left_hip, left_foot, 69.0 * scale, 67.0 * scale, -1.0)
    var right_leg: Dictionary = ik.solve_two_bone(right_hip, right_foot, 69.0 * scale, 67.0 * scale, 1.0)
    var left_arm: Dictionary = ik.solve_two_bone(left_shoulder, left_hand, 47.0 * scale, 43.0 * scale, -1.0)
    var right_arm: Dictionary = ik.solve_two_bone(right_shoulder, right_hand, 47.0 * scale, 43.0 * scale, 1.0)
    var pants := Color("b64c52")
    var shirt := Color("dce6ef")
    var skin := Color("e7b28e")
    for chain in [left_leg, right_leg]:
        _capsule(image, chain["root"], chain["middle"], 15.0 * scale, pants)
        _capsule(image, chain["middle"], chain["end"], 12.0 * scale, pants)
        _capsule(image, chain["end"], chain["end"] + Vector2(13, 1) * scale, 8.0 * scale, Color("222936"))
    for chain in [left_arm, right_arm]:
        _capsule(image, chain["root"], chain["middle"], 13.0 * scale, shirt)
        _capsule(image, chain["middle"], chain["end"], 10.0 * scale, shirt)
        _capsule(image, chain["end"], chain["end"], 9.0 * scale, skin)
    _capsule(image, chest, hip, 33.0 * scale, shirt)
    var head := chest + Vector2(0, -54) * scale
    _capsule(image, head, head, 28.0 * scale, skin)
    _capsule(image, head + Vector2(-9, -5) * scale, head + Vector2(-9, -5) * scale, 2.5 * scale, Color("25262a"))
    _capsule(image, head + Vector2(9, -5) * scale, head + Vector2(9, -5) * scale, 2.5 * scale, Color("25262a"))
    return image
