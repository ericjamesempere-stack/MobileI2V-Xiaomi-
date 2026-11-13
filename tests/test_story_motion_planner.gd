extends SceneTree
# Run with: godot --headless --path . --script res://tests/test_story_motion_planner.gd
func _initialize() -> void:
    var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
    var data: Dictionary = planner.plan("Il court puis trébuche puis tombe. Ensuite il se relève.", 8.0)
    assert(bool(data.get("ok", false)), "Story should be recognized")
    var steps: Array = data.get("steps", [])
    assert(steps.size() == 4, "Expected four movements")
    assert(steps[0]["action"] == "course")
    assert(steps[1]["action"] == "trebuche")
    assert(steps[2]["action"] == "chute")
    assert(steps[3]["action"] == "releve")
    assert(absf(float(steps[-1]["end"]) - 8.0) < 0.001)
    var empty: Dictionary = planner.plan("...", 5.0)
    assert(not bool(empty.get("ok", true)))
    print("STORY_MOTION_PLANNER_TESTS_OK")
    quit(0)
