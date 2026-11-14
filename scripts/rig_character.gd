extends Control
# V50: personnage articule 2D procedural. 3 cinematiques distinctes
# (danse / marche / salut), pieds au sol, repli avatar explicite.
var phase: float = 0.0
var motion_name: String = "danse"
var reference_head: Texture2D = null
var photo_puppet: bool = false
var source_bounds: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
var motion_speed: float = 0.85
var status_message: String = ""
var facial_expression: String = "neutral"

const INK: Color = Color("172536")
const SKIN: Color = Color("c38b6c")
const SHIRT: Color = Color("f2eee7")
const PANTS: Color = Color("364f67")
const GROUND_Y: float = 870.0

func set_full_body_photo(texture: Texture2D, bounds: Rect2) -> void:
    reference_head = texture
    source_bounds = bounds
    photo_puppet = true
    status_message = "Mode marionnette photo : decoupes par regions fixes, non fiable sur photo arbitraire."
    queue_redraw()

func _clear_photo() -> void:
    photo_puppet = false
    reference_head = null
    status_message = "Detection impossible : avatar 2D generique utilise a la place de la photo."
    queue_redraw()

func _photo_segment(a: Vector2, b: Vector2, width: float, region: Rect2) -> void:
    if reference_head == null:
        return
    var direction: Vector2 = b - a
    var length: float = direction.length()
    if length < 1.0:
        return
    var angle: float = atan2(direction.y, direction.x) - PI / 2.0
    draw_set_transform(a, angle)
    draw_texture_rect_region(reference_head, Rect2(-width / 2.0, 0.0, width, length), region)
    draw_set_transform(Vector2.ZERO, 0.0)

func _src(x: float, y: float, w: float, h: float) -> Rect2:
    var t: Vector2 = reference_head.get_size()
    return Rect2((source_bounds.position + Vector2(x, y) * source_bounds.size) * t, Vector2(w, h) * source_bounds.size * t)

func _joint(p: Vector2, r: float, col: Color) -> void:
    draw_circle(p, r + 2.0, INK)
    draw_circle(p, r, col)

func _limb(a: Vector2, b: Vector2, width: float, col: Color) -> void:
    draw_line(a, b, INK, width + 5.0, true)
    draw_line(a, b, col, width, true)
    _joint(a, width * 0.48, col)
    _joint(b, width * 0.48, col)

func _compute_pose(t: float) -> Dictionary:
    var hip: Vector2
    var chest: Vector2
    var head_tilt: float = 0.0
    var shoulder_l: Vector2
    var shoulder_r: Vector2
    var elbow_l: Vector2
    var elbow_r: Vector2
    var wrist_l: Vector2
    var wrist_r: Vector2
    var knee_l: Vector2
    var knee_r: Vector2
    var ankle_l: Vector2
    var ankle_r: Vector2
    var hip_x: float = 355.0
    if motion_name == "marche":
        var s: float = sin(t * TAU)
        var lift_l: float = maxf(sin(t * TAU), 0.0)
        var lift_r: float = maxf(-sin(t * TAU), 0.0)
        hip = Vector2(hip_x, 575.0 - 6.0 * absf(s))
        chest = hip + Vector2(6.0 * s, -160.0)
        shoulder_l = chest + Vector2(-67.0, -6.0)
        shoulder_r = chest + Vector2(67.0, -6.0)
        elbow_l = shoulder_l + Vector2(-30.0 + 28.0 * s, 70.0)
        elbow_r = shoulder_r + Vector2(30.0 - 28.0 * s, 70.0)
        wrist_l = elbow_l + Vector2(-14.0 + 18.0 * s, 42.0)
        wrist_r = elbow_r + Vector2(14.0 - 18.0 * s, 42.0)
        knee_l = hip + Vector2(-30.0 + 55.0 * s, 120.0 - 30.0 * lift_l)
        knee_r = hip + Vector2(30.0 - 55.0 * s, 120.0 - 30.0 * lift_r)
        ankle_l = Vector2(knee_l.x + 18.0 * s, GROUND_Y - 90.0 * lift_l)
        ankle_r = Vector2(knee_r.x - 18.0 * s, GROUND_Y - 90.0 * lift_r)
        head_tilt = 3.0 * s
    elif motion_name == "chute":
        # One-way fall with distinct body rotation, not the dance fallback.
        var p: float = clampf(t, 0.0, 1.0)
        var angle: float = p * PI * 0.48
        var center := Vector2(355.0 + 115.0 * p, 575.0 + 175.0 * p)
        var up := Vector2(sin(angle), -cos(angle))
        var right := Vector2(cos(angle), sin(angle))
        hip = center
        chest = hip + up * 160.0
        shoulder_l = chest - right * 67.0
        shoulder_r = chest + right * 67.0
        elbow_l = shoulder_l - right * 45.0 + up * 45.0
        elbow_r = shoulder_r + right * 50.0 - up * 15.0
        wrist_l = elbow_l - right * 25.0 + up * 35.0
        wrist_r = elbow_r + right * 30.0 - up * 25.0
        knee_l = hip - right * 40.0 - up * 120.0
        knee_r = hip + right * 40.0 - up * 120.0
        ankle_l = knee_l - up * 105.0
        ankle_r = knee_r - up * 105.0
        head_tilt = 0.0
    elif motion_name == "saut":
        var p: float = clampf(t, 0.0, 1.0)
        var rise: float = 145.0 * sin(p * PI)
        hip = Vector2(355.0, 575.0 - rise)
        chest = hip + Vector2(0.0, -160.0)
        shoulder_l = chest + Vector2(-67.0, -6.0)
        shoulder_r = chest + Vector2(67.0, -6.0)
        elbow_l = shoulder_l + Vector2(-55.0, -55.0)
        elbow_r = shoulder_r + Vector2(55.0, -55.0)
        wrist_l = elbow_l + Vector2(-15.0, -70.0)
        wrist_r = elbow_r + Vector2(15.0, -70.0)
        knee_l = hip + Vector2(-65.0, 105.0)
        knee_r = hip + Vector2(65.0, 105.0)
        ankle_l = knee_l + Vector2(-25.0, 95.0)
        ankle_r = knee_r + Vector2(25.0, 95.0)
        head_tilt = 0.0
    elif motion_name == "salut":
        var w: float = sin(t * TAU * 1.4)
        hip = Vector2(hip_x, 575.0)
        chest = hip + Vector2(0.0, -160.0)
        shoulder_l = chest + Vector2(-67.0, -6.0)
        shoulder_r = chest + Vector2(67.0, -6.0)
        elbow_l = shoulder_l + Vector2(-40.0, 70.0)
        wrist_l = elbow_l + Vector2(-10.0, 55.0)
        elbow_r = shoulder_r + Vector2(55.0, -70.0)
        wrist_r = elbow_r + Vector2(18.0 + 10.0 * w, -35.0)
        knee_l = hip + Vector2(-45.0, 125.0)
        knee_r = hip + Vector2(45.0, 125.0)
        ankle_l = knee_l + Vector2(-8.0, 110.0)
        ankle_r = knee_r + Vector2(8.0, 110.0)
        head_tilt = 2.0 * w
    else:
        var s: float = sin(t * TAU)
        var c: float = cos(t * TAU)
        var bounce: float = 10.0 * absf(sin(t * TAU * 0.5))
        hip = Vector2(hip_x + 25.0 * s, 575.0 - bounce)
        chest = hip + Vector2(12.0 * c, -160.0)
        shoulder_l = chest + Vector2(-67.0, -6.0 + 8.0 * s)
        shoulder_r = chest + Vector2(67.0, -6.0 - 8.0 * s)
        elbow_l = shoulder_l + Vector2(-54.0 - 24.0 * c, 65.0 + 22.0 * s)
        elbow_r = shoulder_r + Vector2(50.0 + 24.0 * c, 65.0 - 25.0 * s)
        wrist_l = elbow_l + Vector2(-25.0 + 30.0 * s, 50.0 - 35.0 * c)
        wrist_r = elbow_r + Vector2(30.0 - 35.0 * s, 45.0 + 40.0 * c)
        knee_l = hip + Vector2(-45.0 + 32.0 * s, 125.0 - 22.0 * maxf(s, 0.0))
        knee_r = hip + Vector2(45.0 - 32.0 * s, 125.0 - 22.0 * maxf(-s, 0.0))
        ankle_l = Vector2(knee_l.x - 18.0 - 10.0 * s, GROUND_Y)
        ankle_r = Vector2(knee_r.x + 18.0 + 10.0 * s, GROUND_Y)
        head_tilt = 6.0 * s
    return {
        "hip": hip, "chest": chest, "shoulder_l": shoulder_l, "shoulder_r": shoulder_r,
        "elbow_l": elbow_l, "elbow_r": elbow_r, "wrist_l": wrist_l, "wrist_r": wrist_r,
        "knee_l": knee_l, "knee_r": knee_r, "ankle_l": ankle_l, "ankle_r": ankle_r,
        "head_tilt": head_tilt,
    }

func _draw() -> void:
    var pose: Dictionary = _compute_pose(phase)
    var hip: Vector2 = pose["hip"]
    var chest: Vector2 = pose["chest"]
    var shoulder_l: Vector2 = pose["shoulder_l"]
    var shoulder_r: Vector2 = pose["shoulder_r"]
    var elbow_l: Vector2 = pose["elbow_l"]
    var elbow_r: Vector2 = pose["elbow_r"]
    var wrist_l: Vector2 = pose["wrist_l"]
    var wrist_r: Vector2 = pose["wrist_r"]
    var knee_l: Vector2 = pose["knee_l"]
    var knee_r: Vector2 = pose["knee_r"]
    var ankle_l: Vector2 = pose["ankle_l"]
    var ankle_r: Vector2 = pose["ankle_r"]
    var head_tilt: float = pose["head_tilt"]
    if photo_puppet and reference_head != null:
        _photo_segment(hip + Vector2(-29, 0), knee_l, 48.0, _src(0.32, 0.49, 0.17, 0.24))
        _photo_segment(knee_l, ankle_l, 40.0, _src(0.32, 0.72, 0.17, 0.25))
        _photo_segment(hip + Vector2(29, 0), knee_r, 48.0, _src(0.51, 0.49, 0.17, 0.24))
        _photo_segment(knee_r, ankle_r, 40.0, _src(0.51, 0.72, 0.17, 0.25))
        _photo_segment(chest, hip, 135.0, _src(0.34, 0.24, 0.32, 0.34))
        _photo_segment(shoulder_l, elbow_l, 37.0, _src(0.20, 0.26, 0.14, 0.19))
        _photo_segment(elbow_l, wrist_l, 30.0, _src(0.18, 0.43, 0.13, 0.17))
        _photo_segment(shoulder_r, elbow_r, 37.0, _src(0.66, 0.26, 0.14, 0.19))
        _photo_segment(elbow_r, wrist_r, 30.0, _src(0.70, 0.43, 0.13, 0.17))
        var face := _src(0.36, 0.03, 0.28, 0.21)
        draw_texture_rect_region(reference_head, Rect2(chest + Vector2(-48, -130), Vector2(96, 108)), face)
        return
    draw_line(Vector2(120, GROUND_Y), Vector2(610, GROUND_Y), Color("66788b"), 3.0, true)
    _limb(hip + Vector2(-29, 0), knee_l, 44.0, PANTS)
    _limb(knee_l, ankle_l, 36.0, PANTS)
    _limb(hip + Vector2(29, 0), knee_r, 44.0, PANTS)
    _limb(knee_r, ankle_r, 36.0, PANTS)
    _limb(ankle_l, ankle_l + Vector2(-24, 5), 19.0, SHIRT)
    _limb(ankle_r, ankle_r + Vector2(24, 5), 19.0, SHIRT)
    draw_colored_polygon(PackedVector2Array([shoulder_l, shoulder_r, hip + Vector2(45, 0), hip + Vector2(-45, 0)]), SHIRT)
    draw_polyline(PackedVector2Array([shoulder_l, shoulder_r, hip + Vector2(45, 0), hip + Vector2(-45, 0), shoulder_l]), INK, 4.0, true)
    _limb(shoulder_l, elbow_l, 33.0, SHIRT)
    _limb(elbow_l, wrist_l, 25.0, SKIN)
    _limb(shoulder_r, elbow_r, 33.0, SHIRT)
    _limb(elbow_r, wrist_r, 25.0, SKIN)
    var head: Vector2 = chest + Vector2(head_tilt, -82.0)
    _limb(chest + Vector2(0, -17), head + Vector2(0, 25), 24.0, SKIN)
    draw_circle(head + Vector2(0, 8), 51.0, INK)
    draw_circle(head, 49.0, SKIN)
    if reference_head != null:
        var tex_size: Vector2 = reference_head.get_size()
        var side: float = minf(tex_size.x, tex_size.y)
        var source := Rect2((tex_size - Vector2(side, side)) * 0.5, Vector2(side, side))
        draw_texture_rect_region(reference_head, Rect2(head - Vector2(42, 42), Vector2(84, 84)), source)
    for i in range(12):
        var angle: float = PI + float(i) * PI / 11.0
        draw_circle(head + Vector2(cos(angle), sin(angle)) * 43.0 + Vector2(0, -8), 14.0, INK)
    draw_arc(head + Vector2(0, 15), 30.0, 0.1, PI - 0.1, 18, INK, 12.0, true)
    draw_circle(head + Vector2(-16, -3), 3.5, INK)
    draw_circle(head + Vector2(16, -3), 3.5, INK)
    if facial_expression == "surprised":
        draw_circle(head + Vector2(0, 19), 11.0, INK)
        draw_circle(head + Vector2(0, 19), 5.0, SKIN)
    elif facial_expression == "happy":
        draw_arc(head + Vector2(0, 10), 17.0, 0.1, PI - 0.1, 18, INK, 4.0, true)
    else:
        draw_arc(head + Vector2(0, 15), 14.0, 0.15, PI - 0.15, 12, INK, 2.8, true)
    draw_circle(head + Vector2(52, 3), 7.0, Color("e8c77a"))

func update_pose(seconds: float, action: String = "danse") -> void:
    motion_name = action
    phase = seconds * motion_speed
    queue_redraw()
func update_expression(_seconds: float, expression: String = "neutral") -> void:
    # Called by frame_generator.gd for every frame; must exist to avoid runtime crash.
    facial_expression = expression
    queue_redraw()
