extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var studio = load("res://scripts/StoryStudio.gd")
    var pipeline = load("res://scripts/StoryFramePipeline.gd")
    var project: Dictionary = studio.storyboard("Une moto roule puis saute", 2.0)
    var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color.RED)
    var root := "user://test_story_pipeline"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) == OK)
    var a := root + "/a.png"
    var b := root + "/b.png"
    assert(image.save_png(a) == OK)
    image.fill(Color.BLUE)
    assert(image.save_png(b) == OK)
    var first: Dictionary = pipeline.attach_scene_frames(project, 0, [a, b])
    assert(first["ok"])
    project = first["project"]
    assert(project["scenes"][1]["reference_previous_frame"] == b)
    var second: Dictionary = pipeline.attach_scene_frames(project, 1, [b, a])
    assert(second["ok"])
    project = second["project"]
    var movie: Dictionary = pipeline.timeline(project, 12)
    assert(movie["ok"])
    assert(movie["frame_count"] == 24)
    assert(movie["frames"][0] == a)
    assert(movie["frames"][12] == b)
    assert(not pipeline.attach_scene_frames(project, 0, ["user://missing_123.png"])["ok"])
    assert(not pipeline.timeline(project, 0)["ok"])
    assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(a)) == OK)
    assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(b)) == OK)
    print("MOBILEI2V_STORY_FRAME_PIPELINE_OK")
    quit(0)
