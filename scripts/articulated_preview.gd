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
    # Opposing arm swing and gentle secondary motion. Keep hand targets
    # inside each two-bone chain's reachable range.
    var left_hand := left_shoulder + Vector2(-30.0 + 20.0 * sin(cycle), 63.0 + 12.0 * cos(cycle)) * scale
    var right_hand := right_shoulder + Vector2(30.0 - 20.0 * sin(cycle), 63.0 - 12.0 * cos(cycle)) * scale
    var left_leg: Dictionary = ik.solve_two_bone(left_hip, left_foot, 69.0 * scale, 67.0 * scale, -1.0)
    var right_leg: Dictionary = ik.solve_two_bone(right_hip, right_foot, 69.0 * scale, 67.0 * scale, 1.0)
    var left_arm: Dictionary = ik.solve_two_bone(left_shoulder, left_hand, 47.0 * scale, 43.0 * scale, -1.0)
    var right_arm: Dictionary = ik.solve_two_bone(right_shoulder, right_hand, 47.0 * scale, 43.0 * scale, 1.0)
    var pants := Color("b64c52")
    var shirt := Color("dce6ef")
    var skin := Color("e7b28e")
    # Each trouser leg is an original transparent painted layer,
    # deformed independently along the thigh and shin IK bones.
    var painter = preload("res://scripts/painted_limb_warp.gd").new()
    var trousers := Image.create(42, 90, false, Image.FORMAT_RGBA8)
    trousers.fill(Color(0, 0, 0, 0))
    for py in range(4, 86):
        for px in range(4, 38):
            var trouser_radius := 15.0 if py < 45 else 12.0
            if absf(float(px) - 21.0) <= trouser_radius:
                var fabric := 0.035 * sin(float(py) * 0.43 + float(px) * 0.71)
                trousers.set_pixel(px, py, Color(0.70 + fabric, 0.28 + fabric, 0.32 + fabric, 1.0))
    for chain in [left_leg, right_leg]:
        var thigh_root: Vector2 = chain["root"]
        var knee: Vector2 = chain["middle"]
        var ankle: Vector2 = chain["end"]
        painter.draw_segment(image, trousers, Vector2(21, 4), Vector2(21, 45), thigh_root, knee, 15.0 * scale)
        painter.draw_segment(image, trousers, Vector2(21, 45), Vector2(21, 85), knee, ankle, 12.0 * scale)
        _capsule(image, ankle, ankle + Vector2(13, 1) * scale, 8.0 * scale, Color("222936"))
    # Painted sleeve pixels are warped along both IK bones. Each segment
    # is a separate transparent layer, preserving original artwork detail.
    var sleeve := Image.create(36, 80, false, Image.FORMAT_RGBA8)
    sleeve.fill(Color(0, 0, 0, 0))
    for py in range(5, 75):
        for px in range(5, 31):
            var distance_from_axis := absf(float(px) - 18.0)
            var sleeve_radius := 12.0 if py < 39 else 9.0
            if distance_from_axis <= sleeve_radius:
                var weave := 0.045 * sin(float(py) * 0.65 + float(px) * 0.9)
                sleeve.set_pixel(px, py, Color(0.82 + weave, 0.88 + weave, 0.94 + weave, 1.0))
    for chain in [left_arm, right_arm]:
        var root_point: Vector2 = chain["root"]
        var middle_point: Vector2 = chain["middle"]
        var end_point: Vector2 = chain["end"]
        painter.draw_segment(image, sleeve, Vector2(18, 5), Vector2(18, 39), root_point, middle_point, 12.0 * scale)
        painter.draw_segment(image, sleeve, Vector2(18, 39), Vector2(18, 74), middle_point, end_point, 9.0 * scale)
        _capsule(image, end_point, end_point, 9.0 * scale, skin)
    # Preserve a painted torso layer instead of covering the limbs with a
    # featureless capsule. The source texture follows chest-to-hip motion.
    var torso_art := Image.create(82, 130, false, Image.FORMAT_RGBA8)
    torso_art.fill(Color(0, 0, 0, 0))
    for py in range(5, 125):
        for px in range(5, 77):
            var waist_taper: float = 33.0 - 5.0 * float(py) / 130.0
            if absf(float(px) - 41.0) <= waist_taper:
                var cloth := 0.03 * sin(float(py) * 0.25 + float(px) * 0.13)
                torso_art.set_pixel(px, py, Color(0.82 + cloth, 0.88 + cloth, 0.94 + cloth, 1.0))
    painter.draw_segment(image, torso_art, Vector2(41, 5), Vector2(41, 125), chest, hip, 33.0 * scale)
    var head := chest + Vector2(0, -54) * scale
    _capsule(image, head, head, 28.0 * scale, skin)
    _capsule(image, head + Vector2(-9, -5) * scale, head + Vector2(-9, -5) * scale, 2.5 * scale, Color("25262a"))
    _capsule(image, head + Vector2(9, -5) * scale, head + Vector2(9, -5) * scale, 2.5 * scale, Color("25262a"))
    return image
