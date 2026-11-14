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
    project = studio.carry_forward(project, 0, "user://frame.png", {"position": [10, 20], "color": "red"})
    scenes = project["scenes"]
    assert(scenes[1]["reference_previous_frame"] == "user://frame.png")
    assert(scenes[1]["entry_state"]["color"] == "red")
    assert(studio.classify_subject("un chat saute") == "animal")
    assert(studio.classify_subject("une ville futuriste") == "place")
    assert(studio.storyboard("Un robot danse", 3.0, "cartoon")["style"] == "cartoon")
    print("MOBILEI2V_STORY_STUDIO_OK")
    quit(0)
