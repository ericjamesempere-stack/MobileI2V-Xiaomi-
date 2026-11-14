extends SceneTree
func _initialize() -> void:
    var planner: RefCounted = load("res://scripts/board_generation_plan.gd").new()
    var result: Dictionary = planner.make_plan("Elle danse puis tombe puis se releve.", ["user://a.png", "user://b.png"], 12.0)
    var boards: Array = result["boards"]
    assert(boards.size() >= 12)
    assert(boards[0]["characters"].size() == 2)
    assert(boards[0]["action"] == "danse")
    assert(boards[-1]["action"] == "releve")
    assert(not planner.validate_drawings(result)["ok"])
    for board in boards:
        board["image_path"] = "user://test.png"
        board["status"] = "approved"
    assert(planner.validate_drawings(result)["ok"])
    print("IMAGE_FIRST_BOARD_PLAN_TESTS_OK")
    quit(0)
