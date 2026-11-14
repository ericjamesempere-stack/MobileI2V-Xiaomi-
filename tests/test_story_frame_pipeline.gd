extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var studio = load("res://scripts/StoryStudio.gd")
    var pipeline = load("res://scripts/StoryFramePipeline.gd")
    var project: Dictionary = studio.storyboard("Une moto roule puis saute", 2.0)
    var root := "user://test_story_pipeline"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) == OK)
    var paths: Array[String] = []
    var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    for i in range(24):
        image.fill(Color(float(i) / 24.0, 0.2, 0.8))
        var p := "%s/source_%03d.png" % [root, i]
        assert(image.save_png(p) == OK)
        paths.append(p)
    var first: Dictionary = pipeline.attach_scene_frames(project, 0, paths.slice(0, 12))
    assert(first["ok"])
    project = first["project"]
    assert(project["scenes"][1]["reference_previous_frame"] == paths[11])
    var second: Dictionary = pipeline.attach_scene_frames(project, 1, paths.slice(12, 24))
    assert(second["ok"])
    project = second["project"]
    var movie: Dictionary = pipeline.timeline(project, 12)
    assert(movie["ok"])
    assert(movie["frame_count"] == 24)
    assert(movie["frames"][0] == paths[0])
    assert(movie["frames"][12] == paths[12])
    assert(not pipeline.attach_scene_frames(project, 0, ["user://missing_123.png"])["ok"])
    assert(not pipeline.timeline(project, 0)["ok"])
    var export_dir := root + "/export"
    var exported: Dictionary = pipeline.export_png_sequence(project, export_dir, 12)
    assert(exported["ok"], "PNG sequence export failed")
    assert(exported["frame_count"] == 24)
    assert(FileAccess.file_exists(export_dir + "/frame_000000.png"))
    assert(FileAccess.file_exists(export_dir + "/frame_000023.png"))
    assert(FileAccess.file_exists(export_dir + "/manifest.json"))
    assert(exported["video_encoded"] == false)
    var stills: Dictionary = studio.storyboard("Une moto roule", 1.0)
    stills = pipeline.attach_scene_frames(stills, 0, [paths[0]])["project"]
    var rejected: Dictionary = pipeline.export_png_sequence(stills, root + "/bad_export", 12)
    assert(not rejected["ok"])
    assert(rejected["error"] == "insufficient_motion_frames")
    for i in range(24):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(export_dir + "/frame_%06d.png" % i))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(export_dir + "/manifest.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(export_dir))
    for p in paths:
        assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(p)) == OK)
    print("MOBILEI2V_STORY_FRAME_PIPELINE_OK")
    quit(0)
