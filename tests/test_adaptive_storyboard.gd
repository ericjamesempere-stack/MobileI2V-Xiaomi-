extends SceneTree
# godot --headless --path . --script res://tests/test_adaptive_storyboard.gd
func _initialize() -> void:
    var script: Script = load("res://scripts/storyboard.gd")
    assert(script != null, "Storyboard script should load")
    var board: Control = script.new()
    var still_count: int = board.call("_adaptive_pose_count", "Il attend", 6.0)
    var moving_count: int = board.call("_adaptive_pose_count", "Il court puis trébuche puis tombe", 6.0)
    assert(still_count >= 12 and still_count <= 48)
    assert(moving_count > still_count, "Complex story should get more poses")
    assert(board.call("_adaptive_pose_count", "Il court puis tombe", 60.0) <= 48)
    print("ADAPTIVE_STORYBOARD_TESTS_OK")
    board.queue_free()
    quit(0)
