extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var studio = load("res://scripts/StoryStudio.gd")
    var planner = load("res://scripts/StoryActionPlanner.gd")
    var project: Dictionary = studio.storyboard("Il court puis tombe puis saute", 3.0)
    var planned: Dictionary = planner.plan(project, 12)
    assert(planned["ok"])
    var scenes: Array = planned["project"]["scenes"]
    assert(scenes.size() == 3)
    assert(scenes[0]["motion_action"] == "run")
    assert(scenes[1]["motion_action"] == "fall")
    assert(scenes[2]["motion_action"] == "jump")
    assert(scenes[1]["motion_beats"][3] == "ground")
    assert(scenes[0]["required_unique_frames"] == 12)
    assert(not planned["project"]["motion_rendered"])
    assert(not project["scenes"][0].has("motion_action"))
    var unknown: Dictionary = planner.plan(studio.storyboard("Une créature se métamorphose", 1.0))
    assert(unknown["project"]["scenes"][0]["motion_action"] == "unsupported")
    assert(not unknown["project"]["scenes"][0]["motion_supported"])
    print("MOBILEI2V_STORY_ACTION_PLANNER_OK")
    quit(0)
