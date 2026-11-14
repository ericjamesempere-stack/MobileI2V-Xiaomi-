extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var studio = load("res://scripts/StoryStudio.gd")
    var planner = load("res://scripts/StoryActionPlanner.gd")
    var renderer = load("res://scripts/ProceduralPoseRenderer.gd")
    var pipeline = load("res://scripts/StoryFramePipeline.gd")
    var project: Dictionary = studio.storyboard("Il court puis saute", 2.0)
    project = planner.plan(project, 12)["project"]
    var root := "user://test_procedural_renderer"
    var rendered: Dictionary = renderer.render(project, root, 12)
    assert(rendered["ok"], str(rendered))
    assert(rendered["frames"] == 24)
    var first := "%s/rendered/scene_000/frame_000000.png" % root
    var later := "%s/rendered/scene_000/frame_000005.png" % root
    assert(FileAccess.file_exists(first))
    assert(FileAccess.get_sha256(first) != FileAccess.get_sha256(later), "Rendered poses must change")
    var imported: Dictionary = pipeline.import_rendered_scenes(project, root)
    assert(imported["ok"], str(imported))
    var sequence: Dictionary = pipeline.export_png_sequence(imported["project"], root + "/sequence", 12)
    assert(sequence["ok"], str(sequence))
    assert(sequence["frame_count"] == 24)
    print("MOBILEI2V_PROCEDURAL_RENDERER_OK")
    quit(0)
