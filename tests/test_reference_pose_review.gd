extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var reviewer = load("res://scripts/ReferencePoseReview.gd")
    var root := "user://test_reference_pose_review"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) == OK)
    var plan := {"ok": true, "keyframes": [{"frame_index": 0}, {"frame_index": 6}]}
    var absent: Dictionary = reviewer.prepare(plan, root, root + "/sheet.png")
    assert(absent.get("error") == "keyframe_missing")
    var first := Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
    first.fill(Color.RED)
    var second := Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
    second.fill(Color.BLUE)
    assert(first.save_png(root + "/keyframe_000000.png") == OK)
    assert(second.save_png(root + "/keyframe_000006.png") == OK)
    var result: Dictionary = reviewer.prepare(plan, root, root + "/sheet.png")
    assert(result.get("ok", false), str(result))
    assert(result["keyframes"] == 2)
    assert(result["requires_user_approval"])
    assert(not result["video_ready"])
    assert(FileAccess.file_exists(result["sheet_path"]))
    print("MOBILEI2V_REFERENCE_POSE_REVIEW_OK")
    quit(0)
