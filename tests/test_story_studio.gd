extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var studio = load("res://scripts/StoryStudio.gd")
    assert(studio != null, "StoryStudio missing")
    var project: Dictionary = studio.storyboard(
        "Une moto roule puis saute ensuite atterrit sur Mars", 15.0, "manga", ["photo_source.png"]
    )
    var scenes: Array = project["scenes"]
    assert(scenes.size() == 3, "Expected three sequential scenes")
    assert(project["subject_type"] == "vehicle", "Motorcycle must be a vehicle")
    assert(project["reference_count"] == 1, "Reference should be preserved")
    assert(is_equal_approx(float(scenes[0]["duration_seconds"]), 5.0))
    assert(scenes[1]["continuity_from"] == "scene_000")
    assert(scenes[0]["entity_ids"] == scenes[1]["entity_ids"], "Entity identity must persist")
    assert(scenes[0]["generation_prompt"].contains("manga"), "Style must reach generation prompt")
    project = studio.carry_forward(project, 0, "user://frame.png", {"position": [10, 20], "color": "red"})
    scenes = project["scenes"]
    assert(scenes[1]["reference_previous_frame"] == "user://frame.png")
    assert(scenes[1]["entry_state"]["color"] == "red")
    assert(project["entities"].size() == 1, "One persistent subject expected")
    project["reference_paths"] = ["user://reference.png"]
    var request: Dictionary = studio.image_request(project, 1)
    assert(request["previous_frame"] == "user://frame.png")
    assert(request["reference_images"].size() == 2)
    assert(request["status"] == "requires_image_model")
    assert(studio.image_request(project, 999).has("error"))
    var exported: Dictionary = studio.export_requests(project, "user://test_scene_requests")
    assert(exported["ok"])
    assert(exported["count"] == 3)
    var request_file := FileAccess.open(exported["requests"][1], FileAccess.READ)
    assert(request_file != null)
    var saved_request: Variant = JSON.parse_string(request_file.get_as_text())
    request_file.close()
    assert(saved_request is Dictionary)
    assert(saved_request["previous_frame"] == "user://frame.png")
    for saved_path in exported["requests"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_scene_requests"))
    assert(studio.classify_subject("un chat saute") == "animal")
    assert(studio.classify_subject("une ville futuriste") == "place")
    assert(studio.storyboard("Un robot danse", 3.0, "cartoon")["style"] == "cartoon")
    var empty_story: Dictionary = studio.storyboard("", 2.0, "unknown")
    assert(empty_story["scenes"].size() == 1, "Empty prompt fallback should be safe")
    assert(empty_story["style"] == "manga", "Unsupported styles should use manga")
    var custom_story: Dictionary = studio.storyboard("une maison puis un arbre", 24.0, "bd")
    assert(custom_story["scenes"].size() == 2)
    assert(is_equal_approx(float(custom_story["scenes"][1]["start_seconds"]), 12.0))
    print("MOBILEI2V_STORY_STUDIO_OK")
    quit(0)
