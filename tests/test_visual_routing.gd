extends SceneTree

func _initialize() -> void:
    var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
    var result: Dictionary = planner.plan("Le personnage se transforme en dragon et apres il prend le metro puis il joue au foot.", 12.0)
    var steps: Array = result.get("steps", [])
    assert(steps.size() == 3, "Expected transformation, subway, football as separate scenes")
    assert(steps[0]["action"] == "transformation")
    assert(steps[1]["action"] == "metro")
    assert(steps[2]["action"] == "football")
    var director: RefCounted = load("res://scripts/story_director.gd").new()
    var production: Dictionary = director.build("Le personnage se transforme en dragon et apres il prend le metro puis il joue au foot.", 12.0, "user://reference.png")
    var scenes: Array = production["scenes"]
    assert(scenes.size() == 3)
    for scene in scenes:
        assert(scene["requires_visual_generation"] == true)
        assert(scene["visual_engine_status"] == "blocked")
    print("PASS visual routing: no fake generative completion")
    quit()
