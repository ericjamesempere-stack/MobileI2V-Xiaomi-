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
    assert(scenes[0]["continuity"]["preserve_last_pose"] == false)
    for i in range(1, scenes.size()):
        assert(scenes[i]["continuity"]["from_scene"] == scenes[i - 1]["id"])
        assert(scenes[i]["continuity"]["previous_action"] == scenes[i - 1]["action"])
        assert(scenes[i]["continuity"]["preserve_last_pose"] == true)
        assert(scenes[i]["continuity"]["transition_frames"] > 0)
    for scene in scenes:
        assert(scene["end_frame"] > scene["start_frame"])
        assert(not scene["keyframes"].is_empty())
        assert(not str(scene["source_text"]).is_empty())
    var unknown_project: Dictionary = director.build("Il fait un salto sur une main.", 3.0)
    assert(unknown_project["scenes"].size() == 1)
    assert(unknown_project["scenes"][0]["motion_generation_required"])
    var blank_artwork := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    var missing_poses: Dictionary = director.render_scene_from_keyframes(
        unknown_project["scenes"][0], blank_artwork, [], [])
    assert(not missing_poses["ok"])
    assert(missing_poses["requires_pose_generation"])
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
    var pose_a: Array = []
    var pose_b: Array = []
    for landmark in range(33):
        pose_a.append({"x": 0.3, "y": 0.4, "visibility": 0.99})
        pose_b.append({"x": 0.7, "y": 0.6, "visibility": 0.99})
    var pose_map: Dictionary = {}
    for scene in scenes:
        pose_map[scene["id"]] = {"start": pose_b, "end": pose_a}
    var joined: Dictionary = director.build_pose_transitions(project, pose_map)
    assert(joined["ok"])
    assert(joined["transitions"].size() == 3)
    assert(joined["transitions"][0]["count"] == 6)
    assert(float(joined["transitions"][0]["poses"][0][11]["x"]) > 0.3)
    assert(float(joined["transitions"][0]["poses"][-1][11]["x"]) < 0.7)
    var rendered: Dictionary = director.render_pose_transitions(joined, 96, 128)
    assert(rendered["ok"])
    assert(rendered["frames"].size() == 3)
    assert(rendered["frames"][0]["images"].size() == 6)
    assert(rendered["frames"][0]["images"][0].get_size() == Vector2i(96, 128))
    assert(rendered["transparent_background"])
    assert(rendered["frames"][0]["images"][0].get_pixel(0, 0).a < 0.01)
    var opaque: Dictionary = director.render_pose_transitions(joined, 96, 128, false)
    assert(opaque["ok"])
    assert(opaque["frames"][0]["images"][0].get_pixel(0, 0).a > 0.99)
    assert(not director.render_pose_transitions(joined, 16, 16)["ok"])
    var absent: Dictionary = director.build_pose_transitions(project, {})
    assert(not absent["ok"])
    assert(absent["errors"].size() == 3)
    var unsupported: Dictionary = director.build("Une voiture a un accident et les secours arrivent.", 180.0)
    assert(not unsupported["warnings"].is_empty(), "Unsupported semantic actions must not be silently invented")
    print("STORY_DIRECTOR_TESTS_OK")
    quit(0)
