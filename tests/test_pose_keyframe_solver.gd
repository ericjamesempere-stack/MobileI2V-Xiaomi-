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
    assert(absf(float(result["frames"][0][11]["x"]) - 0.4) < 0.001)
    assert(absf(float(result["frames"][60][11]["x"]) - 0.6) < 0.001)
    assert(not solver.generate([{"time": 0.0, "pose": _pose(0.0)}], 30)["ok"])
    assert(not solver.generate([
        {"time": 0.0, "pose": _pose(0.0)},
        {"time": 0.0, "pose": _pose(0.1)}
    ], 30)["ok"])
    print("POSE_KEYFRAME_SOLVER_TESTS_OK")
    quit(0)
