extends RefCounted
# Two-bone inverse kinematics for a future textured 2D character rig.
# Coordinates are in pixels. Joint positions are solved without
# stretching either bone, unlike the old image-patch rotation approach.

func solve_two_bone(root: Vector2, target: Vector2, upper_length: float, lower_length: float, bend_sign: float = 1.0) -> Dictionary:
    if upper_length <= 0.0 or lower_length <= 0.0:
        return {"ok": false, "reason": "Invalid bone lengths"}
    var delta: Vector2 = target - root
    var distance: float = delta.length()
    var minimum: float = absf(upper_length - lower_length) + 0.001
    var maximum: float = upper_length + lower_length - 0.001
    var reachable: bool = distance >= minimum and distance <= maximum
    var clamped_distance: float = clampf(distance, minimum, maximum)
    var direction: Vector2 = delta.normalized() if distance > 0.0001 else Vector2.DOWN
    var endpoint: Vector2 = root + direction * clamped_distance
    var projected: float = (upper_length * upper_length - lower_length * lower_length + clamped_distance * clamped_distance) / (2.0 * clamped_distance)
    var height: float = sqrt(maxf(0.0, upper_length * upper_length - projected * projected))
    var perpendicular := Vector2(-direction.y, direction.x)
    var elbow: Vector2 = root + direction * projected + perpendicular * height * (1.0 if bend_sign >= 0.0 else -1.0)
    return {
        "ok": true,
        "root": root,
        "middle": elbow,
        "end": endpoint,
        "reachable": reachable,
        "upper_length": upper_length,
        "lower_length": lower_length
    }

func smooth_motion(t: float) -> float:
    var u: float = clampf(t, 0.0, 1.0)
    return u * u * (3.0 - 2.0 * u)
