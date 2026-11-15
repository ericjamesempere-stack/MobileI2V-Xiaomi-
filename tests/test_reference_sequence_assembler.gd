extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var assembler = load("res://scripts/ReferenceSequenceAssembler.gd")
    var source := "user://test_reference_sequence_source"
    var target := "user://test_reference_sequence_target"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source)) == OK)
    var plan := {"ok": true, "fps": 12, "frames": [{"scene_index": 0}, {"scene_index": 0}]}
    var absent: Dictionary = assembler.assemble(plan, source, target)
    assert(absent.get("error") == "missing_generated_frame")
    var a := Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
    var b := Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
    a.fill(Color.RED)
    b.fill(Color.BLUE)
    assert(a.save_png(source + "/frame_000000.png") == OK)
    assert(b.save_png(source + "/frame_000001.png") == OK)
    var result: Dictionary = assembler.assemble(plan, source, target)
    assert(result.get("ok", false), str(result))
    assert(result["frame_count"] == 2)
    assert(result["review_required"])
    assert(not result["mp4_encoded"])
    assert(FileAccess.file_exists(target + "/frame_000001.png"))
    print("MOBILEI2V_REFERENCE_SEQUENCE_ASSEMBLER_OK")
    quit(0)
