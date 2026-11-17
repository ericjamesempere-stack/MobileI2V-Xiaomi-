extends SceneTree
# Diagnostic with a documented assistant annotation of a public synthetic image.
# It never marks that annotation as an automatic vision-model result.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var source := Image.new()
    assert(source.load("res://validation/v54-poses/reference.png") == OK)
    var analyzer: RefCounted = load("res://scripts/reference_visual_analysis.gd").new()
    var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/universal_a_annotation.json"))
    scene["reference_sha"] = analyzer.reference_sha(source)
    var pipeline: Node = load("res://scripts/universal_board_pipeline.gd").new()
    root.add_child(pipeline)
    # The official vision demo has already returned error/null for this exact
    # public fixture with both URL and correctly uploaded FileData inputs.
    pipeline.worker.vision_failed = true
    var folder: String = "res://validation/v54-universal-a"
    var plan: Dictionary = pipeline.prepare_from_scene(source, scene, 5.0, folder, true)
    assert(plan["ok"] and not plan["semantic_analysis"])
    print("A_DENSITY " + JSON.stringify({"keyposes":plan["keyposes"],"intermediates":plan["intermediate_drawings"],"video_frames":plan["video_frames"],"steps":plan["steps"]}))
    var result: Dictionary = await pipeline.generate_keyposes(source, plan, "original", folder)
    var status: Dictionary = {"generation":result,"automatic_vision":"blocked: published demo returned error/null","test_A_passed":false,"tests_B_C_D":"not_started","human_approved":false}
    var file := FileAccess.open(folder.path_join("test_status.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(status,"  "))
    file.close()
    print("UNIVERSAL_A_RESULT " + JSON.stringify(status))
    pipeline.queue_free()
    await process_frame
    quit(0 if result["ok"] else 1)
