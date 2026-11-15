extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var importer = load("res://scripts/ReferenceKeyframeImporter.gd")
    var folder := "user://test_reference_keyframe_importer"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
    var schedule_data := {
        "ok": true,
        "keyframes": [{"frame_index": 0}, {"frame_index": 6}]
    }
    var missing: Dictionary = importer.inspect(schedule_data, folder)
    assert(missing.get("error") == "keyframe_missing")
    var red := Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
    red.fill(Color.RED)
    var blue := Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
    blue.fill(Color.BLUE)
    var first := folder + "/keyframe_000000.png"
    var second := folder + "/keyframe_000006.png"
    assert(red.save_png(first) == OK)
    assert(blue.save_png(second) == OK)
    var valid: Dictionary = importer.inspect(schedule_data, folder)
    assert(valid.get("ok", false), str(valid))
    assert(valid["count"] == 2)
    assert(not valid["identity_verified"])
    assert(red.save_png(second) == OK)
    var duplicate: Dictionary = importer.inspect(schedule_data, folder)
    assert(duplicate.get("error") == "identical_keyframes")
    print("MOBILEI2V_KEYFRAME_IMPORTER_OK")
    quit(0)
