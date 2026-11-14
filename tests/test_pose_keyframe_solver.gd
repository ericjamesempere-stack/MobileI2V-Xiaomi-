extends SceneTree

func _pose(offset: float) -> Array:
    var points: Array = []
    for i in range(33):
        points.append({"x": 0.4 + offset, "y": 0.1 + float(i) * 0.02, "visibility": 1.0})
    return points

func _initialize() -> void:
    var solver: RefCounted = load("res://scripts/pose_keyframe_solver.gd").new()
    var result: Dictionary = solver.generate([
        {"time": 0.0, "pose": _pose(0.0)},
        {"time": 0.4, "pose": _pose(0.1)},
        {"time": 1.0, "pose": _pose(0.2)}
    ], 61)
    assert(result["ok"])
    assert(result["count"] == 61)
    assert(solver.validate_joint_velocity(result["frames"])["ok"])
    var teleported: Array = result["frames"].duplicate(true)
    teleported[20][15]["x"] = float(teleported[20][15]["x"]) + 0.5
    assert(not solver.validate_joint_velocity(teleported)["ok"])
    var repaired: Dictionary = solver.repair_isolated_spikes(teleported)
    assert(repaired["ok"])
    assert(repaired["repair_count"] == 1)
    assert(solver.validate_joint_velocity(repaired["frames"])["ok"])
    assert(not solver.validate_joint_velocity(teleported)["ok"], "Source frames must not be modified")
    var clean: Dictionary = solver.repair_isolated_spikes(result["frames"])
    assert(clean["ok"] and clean["repair_count"] == 0)
    var lengths: Dictionary = solver.validate_bone_lengths(result["frames"])
    assert(lengths["ok"], "Rigid translation must preserve bone lengths")
    var distorted: Array = result["frames"].duplicate(true)
    distorted[30][15]["x"] = float(distorted[30][15]["x"]) + 0.4
    assert(not solver.validate_bone_lengths(distorted)["ok"], "Sudden arm stretching must be flagged")
    assert(absf(float(result["frames"][0][11]["x"]) - 0.4) < 0.001)
    assert(absf(float(result["frames"][60][11]["x"]) - 0.6) < 0.001)
    assert(not solver.generate([{"time": 0.0, "pose": _pose(0.0)}], 30)["ok"])
    assert(not solver.generate([
        {"time": 0.0, "pose": _pose(0.0)},
        {"time": 0.0, "pose": _pose(0.1)}
    ], 30)["ok"])
    print("POSE_KEYFRAME_SOLVER_TESTS_OK")
    quit(0)
