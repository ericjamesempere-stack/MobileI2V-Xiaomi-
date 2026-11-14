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
    var sequence: Dictionary = solver.generate_action_sequence([
        {"action": "walk", "frame_count": 12, "keyframes": [
            {"time": 0.0, "pose": _pose(0.0)}, {"time": 1.0, "pose": _pose(0.1)}]},
        {"action": "jump", "frame_count": 12, "keyframes": [
            {"time": 0.0, "pose": _pose(0.1)}, {"time": 1.0, "pose": _pose(0.2)}]}
    ], 4)
    assert(sequence["ok"])
    assert(sequence["count"] == 28)
    assert(sequence["boundaries"].size() == 2)
    assert(sequence["boundaries"][1]["transition_frames"] == 4)
    assert(absf(float(sequence["frames"][-1][11]["x"]) - 0.6) < 0.001)
    var walking: Dictionary = solver.generate_gait_keyframes(_pose(0.0), 2, false)
    var running: Dictionary = solver.generate_gait_keyframes(_pose(0.0), 2, true)
    assert(walking["ok"] and running["ok"])
    assert(walking["count"] == 17 and running["count"] == 17)
    assert(walking["action"] == "marche" and running["action"] == "course")
    assert(absf(float(walking["frames"][0][15]["x"]) - float(walking["frames"][-1][15]["x"])) < 0.0001)
    assert(absf(float(running["frames"][2][15]["x"]) - float(running["frames"][0][15]["x"])) > 0.01)
    var accelerated: Dictionary = solver.generate_walk_to_run(_pose(0.0), 2, 2, 8)
    assert(accelerated["ok"])
    assert(accelerated["count"] == 42)
    assert(accelerated["boundaries"].size() == 3)
    assert(accelerated["boundaries"][1]["action"] == "acceleration")
    assert(accelerated["frames"][0] is Array)
    print("POSE_KEYFRAME_SOLVER_TESTS_OK")
    quit(0)
