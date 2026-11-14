extends RefCounted
class_name MotionPlanner

# Deterministic, offline keyframe planner. This plans poses; a rig renderer
# must apply the resulting joint positions to produce visible animation.
const JOINTS := ["root", "head", "left_hand", "right_hand", "left_foot", "right_foot"]

static func action_from_text(prompt: String) -> String:
    var s := prompt.to_lower()
    if "tombe" in s or "chute" in s or "fall" in s:
        return "run_fall" if ("cour" in s or "run" in s) else "fall"
    if "cour" in s or "run" in s:
        return "run"
    if "saute" in s or "jump" in s:
        return "jump"
    if "salut" in s or "wave" in s:
        return "wave"
    if "dans" in s or "dance" in s:
        return "dance"
    return "idle"

static func pose(action: String, t: float, duration: float = 5.0) -> Dictionary:
    var d := maxf(duration, 0.01)
    var phase := clampf(t / d, 0.0, 1.0)
    var cycle := sin(t * TAU * 2.0)
    var p := {
        "root": Vector2.ZERO, "head": Vector2(0, -0.8),
        "left_hand": Vector2(-0.55, -0.1), "right_hand": Vector2(0.55, -0.1),
        "left_foot": Vector2(-0.25, 1.0), "right_foot": Vector2(0.25, 1.0),
        "body_rotation": 0.0
    }
    if action == "run" or action == "run_fall":
        p.root = Vector2(phase * 2.0, absf(cycle) * -0.12)
        p.left_hand.y += cycle * 0.45
        p.right_hand.y -= cycle * 0.45
        p.left_foot.y -= maxf(0.0, cycle) * 0.55
        p.right_foot.y -= maxf(0.0, -cycle) * 0.55
    if action == "wave":
        p.right_hand = Vector2(0.55 + 0.12 * cycle, -0.95 + 0.12 * cycle)
    if action == "dance":
        p.root.x = cycle * 0.25
        p.left_hand.y = -0.4 + cycle * 0.4
        p.right_hand.y = -0.4 - cycle * 0.4
    if action == "jump":
        p.root.y = -sin(PI * phase) * 0.9
    if action == "fall" or action == "run_fall":
        var start := 0.15 if action == "fall" else 0.65
        var a := smoothstep(start, minf(start + 0.3, 1.0), phase)
        p.body_rotation = a * PI * 0.5
        p.root.y += a * 0.9
        p.left_hand = p.left_hand.lerp(Vector2(-0.9, 0.65), a)
        p.right_hand = p.right_hand.lerp(Vector2(0.9, 0.65), a)
    return p

static func timeline(prompt: String, duration: float = 5.0, fps: int = 30) -> Array[Dictionary]:
    var frames: Array[Dictionary] = []
    var count := maxi(1, ceili(maxf(duration, 0.01) * maxi(fps, 1)))
    var action := action_from_text(prompt)
    for i in range(count):
        var t := float(i) / float(maxi(fps, 1))
        frames.append({"time": t, "action": action, "pose": pose(action, t, duration)})
    return frames
