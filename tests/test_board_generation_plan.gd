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
    var universal: Dictionary = planner.make_plan("Une banane tourne et disparait.", ["user://banana.png"], 4.0)
    var universal_boards: Array = universal["boards"]
    assert(universal_boards.size() >= 4)
    assert(universal_boards[0]["action"] == "rotation")
    assert(universal_boards[-1]["action"] == "apparition")
    assert(planner.phase_at("inconnu", 0.5) != "pose stable")
    assert(planner.phase_at("vol", 0.5) != "")
    var unknown: Dictionary = planner.make_plan("Un objet se décompose en cubes lumineux.", ["user://object.png"], 3.0)
    assert(unknown["boards"][0]["action"] == "inconnu")
    assert(unknown["boards"][0]["phase"] != "pose stable")
    print("IMAGE_FIRST_BOARD_PLAN_TESTS_OK")
    quit(0)
