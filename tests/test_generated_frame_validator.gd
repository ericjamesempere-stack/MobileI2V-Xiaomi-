extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var validator = load("res://scripts/GeneratedFrameValidator.gd")
    var folder := "user://generated_frame_validator_test"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
    var a := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
    a.fill(Color.RED)
    var b := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
    b.fill(Color.BLUE)
    var p0 := folder + "/a.png"
    var p1 := folder + "/b.png"
    assert(a.save_png(p0) == OK)
    assert(b.save_png(p1) == OK)
    var plan := {"ok": true, "frames": [{"scene_index": 0}, {"scene_index": 1}]}
    var good_paths: Array[String] = [p0, p1]
    var good: Dictionary = validator.inspect(plan, good_paths)
    assert(good.get("ok", false), str(good))
    assert(good["review_required"])
    assert(not good["identity_verified"])
    assert(good["scene_starts"].size() == 2)
    var duplicate_paths: Array[String] = [p0, p0]
    var duplicate: Dictionary = validator.inspect(plan, duplicate_paths)
    assert(duplicate.get("error") == "duplicate_adjacent_frames")
    var missing_paths: Array[String] = [p0, folder + "/missing.png"]
    var missing: Dictionary = validator.inspect(plan, missing_paths)
    assert(missing.get("error") == "missing_generated_frame")
    var mismatch_paths: Array[String] = [p0]
    var mismatch: Dictionary = validator.inspect(plan, mismatch_paths)
    assert(mismatch.get("error") == "frame_count_mismatch")
    var storyboard_entries: Array = [{"path": p0, "video_frame": 0}, {"path": p1, "video_frame": 5}]
    var storyboard_check: Dictionary = validator.inspect_storyboard_entries(storyboard_entries)
    assert(storyboard_check.get("ok", false), str(storyboard_check))
    assert(storyboard_check["drawings"] == 2)
    assert(not storyboard_check["identity_verified"])
    var broken_entries: Array = [{"path": p0}, {"path": folder + "/missing.png"}]
    assert(validator.inspect_storyboard_entries(broken_entries).get("error") == "missing_generated_drawing")
    assert(validator.inspect_storyboard_entries([]).get("error") == "no_generated_drawings")
    var same: Dictionary = validator.inspect_visual_change(a, a)
    assert(same.get("ok", false))
    assert(same["warnings"].has("near_identical_to_reference"))
    assert(same["warnings"].has("near_uniform_candidate"))
    assert(same["review_required"] and not same["identity_verified"] and not same["pose_verified"])
    var changed: Dictionary = validator.inspect_visual_change(a, b)
    assert(changed.get("ok", false))
    assert(not changed["warnings"].has("near_identical_to_reference"))
    assert(changed["mean_pixel_difference"] > 0.1)
    assert(validator.inspect_visual_change(null, b).get("error") == "missing_visual_input")
    print("MOBILEI2V_GENERATED_FRAME_VALIDATOR_OK")
    quit(0)
