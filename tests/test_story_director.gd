extends SceneTree
func _initialize() -> void:
    var director: RefCounted = load("res://scripts/story_director.gd").new()
    var project: Dictionary = director.build("Il court puis trebuche puis tombe. Ensuite il se releve.", 12.0, "user://reference.png")
    assert(project["schema_version"] == 1)
    assert(project["fps"] == 30)
    assert(project["total_frames"] == 360)
    var scenes: Array = project["scenes"]
    assert(scenes.size() == 4, "Expected four chronological actions")
    assert(scenes[0]["action"] == "course")
    assert(scenes[1]["action"] == "trebuche")
    assert(scenes[2]["action"] == "chute")
    assert(scenes[3]["action"] == "releve")
    for scene in scenes:
        assert(scene["end_frame"] > scene["start_frame"])
        assert(not scene["keyframes"].is_empty())
        assert(not str(scene["source_text"]).is_empty())
    var pending: Dictionary = director.validate_for_animation(project)
    assert(not pending["ok"], "Unapproved drawings must block animation")
    for scene in scenes:
        for pose in scene["keyframes"]:
            pose["status"] = "approved"
    assert(not director.validate_for_animation(project)["ok"], "Approved flags alone cannot replace missing images and hashes")
    var missing_motion: Dictionary = director.build("Il entre dans le métro puis court.", 6.0)
    assert(missing_motion["scenes"].size() == 2)
    assert(missing_motion["scenes"][0]["action"] == "metro")
    assert(missing_motion["scenes"][0]["rig_motion"] == "none")
    assert(missing_motion["scenes"][0]["status"] == "needs_motion_implementation")
    assert(bool(missing_motion["scenes"][0]["requires_visual_generation"]))
    var unsupported: Dictionary = director.build("Une voiture a un accident et les secours arrivent.", 180.0)
    assert(not unsupported["warnings"].is_empty(), "Unsupported semantic actions must not be silently invented")
    print("STORY_DIRECTOR_TESTS_OK")
    quit(0)
