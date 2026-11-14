extends SceneTree

func _initialize() -> void:
    var solver = load("res://scripts/two_bone_ik.gd").new()
    var root := Vector2(120, 100)
    var target := Vector2(150, 170)
    var result: Dictionary = solver.solve_two_bone(root, target, 50.0, 40.0, 1.0)
    assert(bool(result.get("ok", false)), "IK solver failed")
    assert(bool(result.get("reachable", false)), "Reachable target incorrectly rejected")
    assert(absf((result["middle"] - root).length() - 50.0) < 0.01, "Upper bone stretched")
    assert(absf((result["end"] - result["middle"]).length() - 40.0) < 0.01, "Lower bone stretched")
    var far: Dictionary = solver.solve_two_bone(root, Vector2(120, 500), 50.0, 40.0)
    assert(bool(far.get("ok", false)) and not bool(far.get("reachable", true)), "Unreachable target not clamped")
    assert(absf((far["middle"] - root).length() - 50.0) < 0.01, "Far target stretched upper bone")
    assert(absf((far["end"] - far["middle"]).length() - 40.0) < 0.01, "Far target stretched lower bone")
    print("TWO_BONE_IK_OK")
    quit(0)
