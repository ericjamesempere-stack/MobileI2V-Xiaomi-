extends RefCounted
# Continuous articulated 2D pose solver. Uses normalized MediaPipe 33-point
# landmarks when supplied; otherwise refuses to claim body detection.
const REQUIRED := [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]
const BONES := [[11,13],[13,15],[12,14],[14,16],[11,12],[11,23],[12,24],[23,24],[23,25],[25,27],[24,26],[26,28]]
func validate_landmarks(points: Array) -> Dictionary:
    if points.size() < 29:
        return {"ok": false, "error": "33 MediaPipe landmarks required"}
    for index in REQUIRED:
        if not points[index] is Dictionary:
            return {"ok": false, "error": "Missing landmark %d" % index}
        var p: Dictionary = points[index]
        if not p.has("x") or not p.has("y") or float(p.get("visibility", 0.0)) < 0.35:
            return {"ok": false, "error": "Low-confidence landmark %d" % index}
    return {"ok": true}

func interpolate_pose(start: Array, finish: Array, fraction: float) -> Array:
    var result: Array = []
    var t: float = clampf(fraction, 0.0, 1.0)
    # Cubic smoothstep: continuous position and zero endpoint velocity.
    t = t * t * (3.0 - 2.0 * t)
    for i in range(mini(start.size(), finish.size())):
        var a: Dictionary = start[i] if start[i] is Dictionary else {}
        var b: Dictionary = finish[i] if finish[i] is Dictionary else {}
        result.append({
            "x": lerpf(float(a.get("x", 0.0)), float(b.get("x", 0.0)), t),
            "y": lerpf(float(a.get("y", 0.0)), float(b.get("y", 0.0)), t),
            "visibility": minf(float(a.get("visibility", 1.0)), float(b.get("visibility", 1.0)))
        })
    return result

func draw_skeleton(image: Image, points: Array, color: Color = Color("#f2b957"), width: int = 3) -> Dictionary:
    var check: Dictionary = validate_landmarks(points)
    if not check["ok"]:
        return check
    var w: int = image.get_width()
    var h: int = image.get_height()
    for bone in BONES:
        var a: Dictionary = points[bone[0]]
        var b: Dictionary = points[bone[1]]
        var start := Vector2(float(a["x"]) * w, float(a["y"]) * h)
        var finish := Vector2(float(b["x"]) * w, float(b["y"]) * h)
        var distance: float = start.distance_to(finish)
        var steps: int = maxi(1, ceili(distance * 2.0))
        for i in range(steps + 1):
            var p: Vector2 = start.lerp(finish, float(i) / steps)
            for oy in range(-width, width + 1):
                for ox in range(-width, width + 1):
                    if ox * ox + oy * oy > width * width:
                        continue
                    var px: int = roundi(p.x) + ox
                    var py: int = roundi(p.y) + oy
                    if px >= 0 and py >= 0 and px < w and py < h:
                        image.set_pixel(px, py, color)
    return {"ok": true, "bones": BONES.size()}

func frames_between(a: Array, b: Array, fps: int, seconds: float) -> Array:
    var count: int = maxi(2, ceili(maxf(0.01, seconds) * maxi(1, fps)))
    var frames: Array = []
    for i in range(count):
        frames.append(interpolate_pose(a, b, float(i) / float(count - 1)))
    return frames
