extends SceneTree

func _initialize() -> void:
    var planner: RefCounted = load("res://scripts/board_generation_plan.gd").new()
    var result: Dictionary = planner.remote_frame("Un homme court et tombe.", 4.0, 8, 0)
    assert(result.get("ok", false))
    var instruction: String = str(result["instruction"])
    assert(instruction.contains("ALL existing subjects"))
    assert(instruction.contains("vehicles, objects, and environmental landmarks"))
    assert(instruction.contains("Move only the subjects and objects involved"))
    assert(instruction.contains("No duplicate subjects"))
    print("V54_FULL_SCENE_BRIEF_OK")
    quit(0)
