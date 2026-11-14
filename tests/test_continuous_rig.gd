extends SceneTree
func _initialize() -> void:
    var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
    var a: Array = []
    var b: Array = []
    for i in range(33):
        a.append({"x": 0.3, "y": 0.4, "visibility": 0.99})
        b.append({"x": 0.7, "y": 0.6, "visibility": 0.99})
    assert(rig.validate_landmarks(a)["ok"])
    var frames: Array = rig.frames_between(a, b, 30, 1.0)
    assert(frames.size() == 30)
    assert(is_equal_approx(float(frames[0][11]["x"]), 0.3))
    assert(is_equal_approx(float(frames[-1][11]["x"]), 0.7))
    for i in range(1, frames.size()):
        assert(float(frames[i][11]["x"]) >= float(frames[i-1][11]["x"]))
    var transition: Dictionary = rig.transition_between_actions(a, b, 6)
    assert(transition["ok"])
    assert(transition["count"] == 6)
    assert(float(transition["frames"][0][11]["x"]) > 0.3)
    assert(float(transition["frames"][-1][11]["x"]) < 0.7)
    assert(float(transition["frames"][0][11]["x"]) < float(transition["frames"][-1][11]["x"]))
    assert(rig.transition_between_actions(a, b, 0)["frames"].is_empty())
    var canvas := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    canvas.fill(Color.BLACK)
    assert(rig.draw_skeleton(canvas, a)["ok"])
    a[11]["visibility"] = 0.1
    assert(not rig.validate_landmarks(a)["ok"])
    assert(not rig.transition_between_actions(a, b, 6)["ok"])
    print("CONTINUOUS_RIG_TESTS_OK")
    quit(0)
