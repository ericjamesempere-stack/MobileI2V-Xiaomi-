extends RefCounted
class_name PoseMapRenderer

# Generates an explicit RGB skeleton-conditioning map for every planned frame.
# These maps are inputs to a pose-conditioned ONNX model, NOT final animation.
# Coordinates are normalized; no Godot scene tree or GPU required.
const BONES := [
    [0, 1], [1, 2], [2, 3], [3, 4], [1, 5], [5, 6], [6, 7],
    [1, 8], [8, 9], [9, 10], [8, 11], [11, 12], [12, 13]
]
const COLORS := [
    Color8(255, 75, 75), Color8(255, 170, 60), Color8(255, 255, 70),
    Color8(120, 255, 80), Color8(50, 220, 190), Color8(70, 130, 255),
    Color8(190, 85, 255)
]

static func render(frame: Dictionary, path: String, width: int = 256, height: int = 256) -> Dictionary:
    if not path.begins_with("user://") or width < 64 or height < 64 or width > 1024 or height > 1024:
        return {"ok": false, "error": "invalid_pose_map_request"}
    var action := str(frame.get("action", "idle")).to_lower()
    var phase := float(frame.get("pose_phase", frame.get("phase", 0.0)))
    var progress := clampf(float(frame.get("action_progress", 0.0)), 0.0, 1.0)
    var center := Vector2(0.5, 0.48)
    var p = frame.get("position", {})
    if p is Dictionary:
        center.x = clampf(0.5 + float(p.get("x", 0.0)) * 0.08, 0.18, 0.82)
        center.y = clampf(0.48 - float(p.get("altitude", 0.0)) * 0.06, 0.2, 0.7)
    var stride := sin(phase * TAU)
    var arm := sin(phase * TAU + PI)
    var running := action.contains("run") or action.contains("cour") or action.contains("march") or action.contains("walk")
    var falling := action.contains("fall") or action.contains("tomb")
    var jumping := action.contains("jump") or action.contains("saut")
    var amount := 0.0
    if running:
        amount = 0.12
    elif jumping:
        amount = 0.07
        center.y -= sin(progress * PI) * 0.12
    elif falling:
        amount = 0.09
    var joints: Array[Vector2] = [
        center + Vector2(0, -0.29), # head
        center + Vector2(0, -0.20), # neck
        center + Vector2(-0.10, -0.17), # left shoulder
        center + Vector2(-0.14 + arm * amount, -0.07),
        center + Vector2(-0.14 + arm * amount * 1.5, 0.05),
        center + Vector2(0.10, -0.17),
        center + Vector2(0.14 - arm * amount, -0.07),
        center + Vector2(0.14 - arm * amount * 1.5, 0.05),
        center + Vector2(0, 0.05), # pelvis
        center + Vector2(-0.07, 0.09),
        center + Vector2(-0.08 + stride * amount, 0.28),
        center + Vector2(0.07, 0.09),
        center + Vector2(0.08 - stride * amount, 0.28),
        center + Vector2(0.09 - stride * amount * 1.5, 0.43)
    ]
    if falling:
        var angle := progress * PI * 0.48
        for i in range(joints.size()):
            joints[i] = center + (joints[i] - center).rotated(angle)
        center.y += progress * 0.18
    var img := Image.create(width, height, false, Image.FORMAT_RGB8)
    img.fill(Color.BLACK)
    for i in range(BONES.size()):
        var a: Vector2 = joints[BONES[i][0]]
        var b: Vector2 = joints[BONES[i][1]]
        _line(img, Vector2i(roundi(a.x * width), roundi(a.y * height)), Vector2i(roundi(b.x * width), roundi(b.y * height)), COLORS[i % COLORS.size()], maxi(2, width / 96))
    for j in joints:
        _dot(img, Vector2i(roundi(j.x * width), roundi(j.y * height)), Color.WHITE, maxi(2, width / 80))
    var directory := path.get_base_dir()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
        return {"ok": false, "error": "pose_map_directory_failed"}
    var result := img.save_png(path)
    return {"ok": result == OK, "path": path, "error": result}

static func render_plan(plan: Dictionary, directory: String, width: int = 256, height: int = 256) -> Dictionary:
    if not plan.get("ok", false) or not directory.begins_with("user://"):
        return {"ok": false, "error": "invalid_plan"}
    var frames: Array = plan.get("frames", [])
    if frames.is_empty():
        return {"ok": false, "error": "no_frames"}
    var generated: Array = []
    for i in range(frames.size()):
        var path := "%s/pose_%06d.png" % [directory, i]
        var result := render(frames[i], path, width, height)
        if not result.get("ok", false):
            return {"ok": false, "error": "pose_render_failed", "index": i}
        var instruction: Dictionary = frames[i]
        instruction["pose_map_path"] = path
        frames[i] = instruction
        generated.append(path)
    plan["frames"] = frames
    return {"ok": true, "plan": plan, "pose_maps": generated}

static func _dot(img: Image, point: Vector2i, color: Color, radius: int) -> void:
    for y in range(point.y - radius, point.y + radius + 1):
        for x in range(point.x - radius, point.x + radius + 1):
            if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height() and (Vector2i(x, y) - point).length_squared() <= radius * radius:
                img.set_pixel(x, y, color)

static func _line(img: Image, a: Vector2i, b: Vector2i, color: Color, radius: int) -> void:
    var steps := maxi(1, maxi(absi(b.x - a.x), absi(b.y - a.y)))
    for i in range(steps + 1):
        var t := float(i) / float(steps)
        _dot(img, Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))), color, radius)
