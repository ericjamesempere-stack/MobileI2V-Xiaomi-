extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var studio = load("res://scripts/StoryStudio.gd")
    var planner = load("res://scripts/StoryActionPlanner.gd")
    var continuity = load("res://scripts/MotionContinuityPlanner.gd")
    var project: Dictionary = studio.storyboard("Il court puis saute puis tombe", 3.0)
    project = planner.plan(project, 12)["project"]
    var timeline: Dictionary = continuity.timeline(project, 12)
    assert(timeline["ok"], str(timeline))
    var frames: Array = timeline["frames"]
    assert(frames.size() == 36)
    var ranges: Array = timeline["scene_ranges"]
    assert(ranges.size() == 3)
    assert(ranges[0]["end"] + 1 == ranges[1]["start"])
    assert(ranges[1]["end"] + 1 == ranges[2]["start"])
    assert(is_equal_approx(float(frames[11]["x"]), float(frames[12]["x"])), "Scene positions must be continuous")
    assert(is_equal_approx(float(frames[23]["x"]), float(frames[24]["x"])), "Jump/fall transition must be continuous")
    var short: Dictionary = studio.storyboard("Il court", 0.1)
    short = planner.plan(short, 12)["project"]
    var tiny: Dictionary = continuity.timeline(short, 12)
    assert(tiny["ok"])
    assert(tiny["frames"].size() == 1)
    print("MOBILEI2V_MOTION_CONTINUITY_OK")
    quit(0)
