extends SceneTree

class OfflineWorker extends "res://scripts/hf_studio_generator.gd":
    var uploads: int = 0
    func _upload_images(_base: String, _images: Array[Image]) -> Dictionary:
        uploads += 1
        return {"ok": false, "error": "SIMULATED provider unavailable"}
    func _redraw_qwen(_reference: Image, _story: String, _style: String, _previous: Image, _variation: bool) -> Dictionary:
        var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
        image.fill(Color("777777"))
        image.fill_rect(Rect2i(0, 0, 256, 512), Color("222222"))
        return {"ok": true, "image": image, "model": "SIMULATED repair, not a real drawing"}

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var reference := Image.new()
    assert(reference.load("res://validation/v54-poses/reference.png") == OK)
    var analyzer: RefCounted = load("res://scripts/reference_visual_analysis.gd").new()
    var planner: RefCounted = load("res://scripts/board_generation_plan.gd").new()
    var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/universal_a_annotation.json"))
    scene["reference_sha"] = analyzer.reference_sha(reference)
    assert(not analyzer.analyze(reference)["semantic_analysis"])
    assert(analyzer.validate_scene(scene, scene["reference_sha"])["ok"])
    assert(not analyzer.validate_scene(scene, "different reference")["ok"])
    var plan: Dictionary = planner.calculate_density(scene, 5.0)
    assert(plan["ok"] and not plan["semantic_analysis"])
    assert(plan["keyposes"] == 8 and plan["intermediate_drawings"] == 51 and plan["video_frames"] == 150)
    assert(plan["total_unique_drawings"] == 59 and plan["intermediates_generated"] == 0)
    assert(not plan["ready_for_animation"] and not plan["interpolation_verified"])
    var total: int = 0
    for step in plan["steps"]:
        total += step["video_frames"]
        assert(step["unique_drawings"] == step["keyposes"] + step["intermediate_drawings"])
    assert(total == 150)
    var previous_frame: int = -1
    for pose in plan["boards"]:
        assert(pose["video_frame"] > previous_frame)
        previous_frame = pose["video_frame"]
    assert(previous_frame == 149)
    assert(not planner.calculate_density(scene, 0.1)["ok"])
    var invalid: Dictionary = scene.duplicate(true)
    invalid["steps"][0]["actor_ids"] = ["absent"]
    assert(not planner.calculate_density(invalid, 5.0)["ok"])
    invalid = scene.duplicate(true)
    invalid["entities"][0]["bbox"] = [0.9, 0.9, 0.5, 0.5]
    assert(not analyzer.validate_scene(invalid, scene["reference_sha"])["ok"])
    invalid = scene.duplicate(true)
    invalid["analysis_origin"] = "live_vision_model"
    assert(not analyzer.validate_scene(invalid, scene["reference_sha"])["ok"])
    var static_scene: Dictionary = scene.duplicate(true)
    static_scene["steps"] = [{"id":"static","instruction":"Keep all entities unchanged","actor_ids":[],"object_ids":[],"weight":1.0,"speed":0.0,"amplitude":0.0,"interaction":0.0,"occlusion":0.0,"camera":0.0,"static":true,"phases":["unchanged scene"]}]
    var still: Dictionary = planner.calculate_density(static_scene, 5.0)
    assert(still["keyposes"] == 1 and still["intermediate_drawings"] == 0 and still["video_frames"] == 150)
    var complex: Dictionary = scene.duplicate(true)
    complex["entities"].append({"id":"e4","kind":"machine","origin":"requested","appearance":"requested moving machine","invariants":["shape"],"allowed_changes":["position"]})
    complex["steps"][0]["actor_ids"].append("e4")
    for feature in ["speed", "amplitude", "interaction", "occlusion", "camera"]:
        complex["steps"][0][feature] = 1.0
    var dense: Dictionary = planner.calculate_density(complex, 5.0)
    assert(dense["total_unique_drawings"] > plan["total_unique_drawings"])
    assert(dense["steps"][0]["mobile_subjects"] == 2)
    var offline := OfflineWorker.new()
    root.add_child(offline)
    var private_fixture := Image.create(32, 32, false, Image.FORMAT_RGB8)
    private_fixture.fill(Color.GREEN)
    assert((await offline.analyze_scene(private_fixture, "move"))["error"] == "external_vision_consent_required")
    assert(offline.uploads == 0)
    offline.remote_vision_consent = true # Fake upload override only: no network.
    assert(not (await offline.analyze_scene(private_fixture, "move"))["ok"])
    assert(offline.uploads == 1)
    assert(not (await offline.analyze_scene(private_fixture, "move"))["ok"])
    assert(offline.uploads == 1)
    assert(offline.extract_vision_text([{"role":"user","content":[{"type":"text","content":"wrong"}]},{"role":"assistant","status":"done","content":[{"type":"text","content":"correct"}]}]) == "correct")
    assert(not offline.batch_prompt(plan["boards"].slice(0, 4)).contains("single subject"))
    var pipeline: Node = load("res://scripts/universal_board_pipeline.gd").new()
    root.add_child(pipeline)
    var folder: String = "user://universal_fixture_%d" % Time.get_ticks_usec()
    assert(not pipeline.prepare_from_scene(reference, scene, 5.0, folder)["ok"])
    var prepared: Dictionary = pipeline.prepare_from_scene(reference, scene, 5.0, folder, true)
    assert(prepared["ok"])
    var restored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("plan.json")))
    assert(pipeline._binding(prepared, 0, "original") == pipeline._binding(restored, 0, "original"))
    assert(pipeline.batch_limit(prepared, 0, "original") == 4)
    assert(pipeline.batch_limit(prepared, 3, "original") == 1)
    pipeline.worker.free()
    pipeline.worker = offline
    root.remove_child(offline)
    pipeline.add_child(offline)
    var original := Image.create(512, 512, false, Image.FORMAT_RGB8)
    original.fill(Color.WHITE)
    original.fill_rect(Rect2i(0, 0, 256, 512), Color.BLACK)
    assert(pipeline._save_drawing(original, prepared, 0, "original", folder, {"ok":true}))
    assert(pipeline._save_drawing(original, prepared, 1, "original", folder, {"ok":true}))
    var first_hash: String = FileAccess.get_sha256(folder.path_join("pose_0000.png"))
    var target_hash: String = FileAccess.get_sha256(folder.path_join("pose_0001.png"))
    assert(pipeline._trusted_previous(folder, 1) == null)
    var repaired: Dictionary = await pipeline.repair_keypose(reference, prepared, "original", folder, 1, "SIMULATED target correction")
    assert(repaired["ok"] and repaired["other_drawings_unchanged"])
    assert(offline.repair_target == null)
    var missing: Dictionary = await pipeline.repair_keypose(reference, prepared, "original", folder, 2, "SIMULATED missing target")
    assert(not missing["ok"] and missing["error"] == "repair_candidate_missing_original_kept")
    assert(FileAccess.get_sha256(folder.path_join("pose_0000.png")) == first_hash)
    assert(FileAccess.get_sha256(folder.path_join("pose_0001.png")) != target_hash)
    assert(pipeline._trusted_previous(folder, 2) == null)
    assert(pipeline._cached(prepared, 1, "original", folder))
    var edited_plan: Dictionary = prepared.duplicate(true)
    edited_plan["boards"][1]["pose"] = "changed physical state"
    assert(pipeline._binding(edited_plan, 0, "original") == pipeline._binding(prepared, 0, "original"))
    assert(pipeline._binding(edited_plan, 1, "original") != pipeline._binding(prepared, 1, "original"))
    pipeline.queue_free()
    await process_frame
    print("UNIVERSAL_BOARD_CONTRACT_OK: deterministic density/roles, no fake vision, consent guard, bounded provider failure, SIMULATED selective repair and unchanged neighbours")
    quit(0)
