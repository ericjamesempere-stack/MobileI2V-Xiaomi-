extends SceneTree
# One bounded diagnostic correction of an already-public synthetic character.
# Never sends a private attachment and never starts tests B/C/D.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var source := Image.new()
    assert(source.load("res://validation/v54-poses/reference.png") == OK)
    var folder: String = "res://validation/v54-universal-a"
    var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("plan.json")))
    var pipeline: Node = load("res://scripts/universal_board_pipeline.gd").new()
    root.add_child(pipeline)
    assert(pipeline.worker._public_synthetic_fixture(source))
    pipeline.worker.vision_failed = true
    var defect: String = OS.get_environment("KARMA_REPAIR_DEFECT")
    if defect.is_empty():
        defect = "Restore the ENTIRE original curved banana from stem to lower tip, with its two original eyes and smile visible. At impact its complete curved body is horizontal against the original flat EMPTY ground line. Existing arms bend and existing legs remain lifted by momentum. Keep the original design and original entity count. No part of the banana is missing."
    var result: Dictionary = await pipeline.repair_keypose(source, plan, "original", folder, 6, defect)
    result["source"] = "public synthetic fixture, no private image"
    result["review_required"] = true
    var file := FileAccess.open(folder.path_join("repair_resume_0006.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(result, "  "))
    file.close()
    print("RESUMED_TARGETED_REPAIR " + JSON.stringify(result))
    pipeline.queue_free()
    await process_frame
    quit(0 if result.get("ok", false) else 1)
