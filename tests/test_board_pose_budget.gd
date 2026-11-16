extends SceneTree

func _initialize() -> void:
    var planner: RefCounted = load("res://scripts/board_pose_budget.gd").new()
    var still: Dictionary = planner.estimate("Le personnage reste immobile.", 2.0, 24)
    assert(still["ok"] and still["selected"] >= 2)
    var motion: Dictionary = planner.estimate("Il court, saute, tombe et rebondit contre un mur.", 5.0, 24)
    assert(motion["ok"] and motion["recommended"] > still["recommended"])
    var capped: Dictionary = planner.estimate("Il court, saute, tombe et rebondit contre un mur.", 5.0, 3)
    assert(capped["ok"] and capped["selected"] == 3 and capped["limited_by_budget"])
    assert(not planner.estimate("", 5.0, 24)["ok"])
    assert(not planner.estimate("court", 0.0, 24)["ok"])
    assert(motion["method"] == "keyword_heuristic_not_semantic")
    print("V54_POSE_BUDGET_OK")
    quit(0)
