extends SceneTree

# Protocol simulation only: no network, no image-generation quality claim.
class ReviewWorker extends "res://scripts/hf_studio_generator.gd":
    var reviewed_ids: Array = []
    var defect_id: String = ""
    var corrected: bool = false
    var mutations: Callable
    func assess_keyposes(_reference: Image, _frames: Array[Image], expected: Array) -> Dictionary:
        var rows: Array = []
        for i in range(expected.size()):
            var id: String = expected[i]["id"]
            reviewed_ids.append(id)
            var bad: bool = id == defect_id and not corrected
            rows.append({"index": i, "identity_match": true, "count_match": true, "action_match": not bad, "environment_match": true, "perspective_match": true, "uncertain": false, "defects": ["wrong contact"] if bad else []})
        if mutations.is_valid():
            mutations.call()
        return {"ok": true, "review": {"frames": rows}, "review_origin": "live_vision_model"}
    func _redraw_qwen(_reference: Image, _story: String, _style: String, _previous: Image, _variation: bool) -> Dictionary:
        corrected = true
        var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
        image.fill(Color.GRAY)
        image.fill_rect(Rect2i(0, 0, 256, 512), Color.BLACK)
        return {"ok": true, "image": image, "model": "SIMULATED"}

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var reference := Image.new()
    assert(reference.load("res://validation/v54-poses/reference.png") == OK)
    var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/universal_a_annotation.json"))
    scene["reference_sha"] = load("res://scripts/reference_visual_analysis.gd").new().reference_sha(reference)
    var pipeline: Node = load("res://scripts/universal_board_pipeline.gd").new()
    root.add_child(pipeline)
    pipeline.worker.free()
    var worker := ReviewWorker.new()
    pipeline.worker = worker
    pipeline.add_child(worker)
    var folder: String = "user://review_resume_%d" % Time.get_ticks_usec()
    var plan: Dictionary = pipeline.prepare_from_scene(reference, scene, 5.0, folder, true)
    assert(plan["ok"])
    var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
    image.fill(Color.WHITE)
    image.fill_rect(Rect2i(0, 0, 256, 512), Color.BLACK)
    for i in range(plan["keyposes"]):
        assert(pipeline._save_drawing(image, plan, i, "original", folder, {"ok": true}))
    worker.defect_id = "pose_0006"
    var reviewed: Dictionary = await pipeline.review_keyposes(reference, plan, folder)
    assert(reviewed["ok"] and reviewed["failed_indices"] == [6])
    assert(worker.reviewed_ids.size() == 8 and not reviewed["fidelity_verified"])
    worker.reviewed_ids.clear()
    reviewed = await pipeline.review_keyposes(reference, plan, folder)
    assert(reviewed["reused_reviews"] == 8 and reviewed["failed_indices"] == [6])
    assert(worker.reviewed_ids.is_empty())
    # A repaired pose invalidates only its own review and is checked immediately.
    var result: Dictionary = await pipeline.review_and_correct(reference, plan, "original", folder)
    assert(result["ok"] and result["fidelity_verified"] and not result["human_approved"])
    assert(worker.reviewed_ids == ["pose_0006"])
    assert(result["reused_reviews"] == 7 and result["reviewed"] == 1)
    worker.reviewed_ids.clear()
    var restored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("plan.json")))
    result = await pipeline.review_and_correct(reference, restored, "original", folder)
    assert(result["fidelity_verified"] and result["reused_reviews"] == 8)
    assert(worker.reviewed_ids.is_empty())
    # A changed instruction cannot inherit a previous passing assessment.
    var changed: Dictionary = plan.duplicate(true)
    changed["boards"][1]["pose"] = "new action"
    result = await pipeline.review_keyposes(reference, changed, folder)
    assert(not result["ok"] and worker.reviewed_ids.is_empty())
    # Another reference is rejected before spending quota.
    var other := Image.create(32, 32, false, Image.FORMAT_RGB8)
    other.fill(Color.RED)
    result = await pipeline.review_keyposes(other, plan, folder)
    assert(not result["ok"] and worker.reviewed_ids.is_empty())
    # A changed PNG, even with matching metadata, invalidates the old review.
    assert(pipeline._save_drawing(image, plan, 6, "original", folder, {"ok": true}))
    worker.corrected = false
    result = await pipeline.review_and_correct(reference, plan, "original", folder)
    assert(result["ok"] and not result["fidelity_verified"])
    assert(result["repairs"][0]["error"] == "repair_budget_already_used")
    assert(worker.reviewed_ids == ["pose_0006"])
    # A file replaced while the reviewer is running cannot receive a passing flag.
    assert(pipeline._save_drawing(image, plan, 2, "original", folder, {"ok": true}))
    worker.mutations = func() -> void:
        var modified: Image = image.duplicate()
        modified.fill(Color.BLUE)
        modified.save_png(folder.path_join("pose_0002.png"))
    result = await pipeline.review_keyposes(reference, plan, folder)
    assert(not result["ok"] and result["error"] == "drawing_changed_during_review")
    pipeline.queue_free()
    await process_frame
    print("UNIVERSAL_REVIEW_RESUME_OK: SIMULATED review reuse, selective recheck, repaired pose verified, stale plan/reference/race rejected, persistent repair budget; no network")
    quit(0)
