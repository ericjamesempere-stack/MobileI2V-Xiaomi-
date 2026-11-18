extends SceneTree
class LocalPipeline extends "res://scripts/universal_board_pipeline.gd":
    func _ready() -> void:
        worker = load("res://scripts/local_studio_generator.gd").new()
        worker.vision_base = OS.get_environment("KARMA_LOCAL_TEST_SERVER")
        worker.drawing_base = worker.vision_base
        add_child(worker)
    func prepare(reference: Image, story: String, seconds: float, folder: String) -> Dictionary:
        var prepared: Dictionary = await super.prepare(reference, story, seconds, folder)
        if prepared.get("ok", false):
            # Nine simulated in-betweens require three bounded batches,
            # exercising automatic continuation in the real local pipeline.
            for i in range(prepared["steps"].size()):
                prepared["steps"][i]["intermediate_drawings"] = 7 if i == 0 else 1
            prepared["intermediate_drawings"] = 9
            prepared["intermediate_schedule"] = load("res://scripts/karma_intermediate_agent.gd").new().schedule(prepared)
            assert(_write(folder.path_join("plan.json"), prepared))
        return prepared
class LocalBoard extends "res://scripts/storyboard.gd":
    func _make_universal_pipeline() -> Node:
        var pipeline := LocalPipeline.new()
        pipeline.local_inference = true
        return pipeline
    func _make_drawing_worker() -> Node:
        var worker: Node = super._make_drawing_worker()
        worker.vision_base = OS.get_environment("KARMA_LOCAL_TEST_SERVER")
        worker.drawing_base = worker.vision_base
        return worker
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var address: String = OS.get_environment("KARMA_LOCAL_TEST_SERVER")
    assert(address.begins_with("http://127.0.0.1:"))
    var board := LocalBoard.new()
    root.add_child(board)
    board.local_mode.set_pressed_no_signal(true)
    # An isolated loopback transport test must never switch to cloud services.
    board.remote_fallback.set_pressed_no_signal(false)
    board.local_auth_input.text = "test-local-secret"
    board.character_description.text = "Une banane vivante"
    await board._create_remote_reference()
    assert(not board.imported_path.is_empty() and board.sources.size() == 1)
    await board._image_chosen("res://validation/v54-poses/reference.png")
    board.style_reference_path = ""
    board.custom_style_input.text = ""
    board.drawing_style.select(0)
    board.action_input.text = "Le personnage court, trébuche puis tombe. SIMULATED local protocol %d" % Time.get_ticks_usec()
    board.duration_input.value = 5
    board.ai_drawings_count.value = 2 # Local generation is not truncated by cloud batch budget.
    await board._friendly_generate()
    if OS.get_environment("KARMA_LOCAL_TEST_SCENARIO") == "outage":
        assert(not board.ai_running and not board._has_current_review())
        assert(board.status.text.contains("SIMULATED engine interruption"), "Show the useful engine error: " + board.status.text)
        assert(board.paths.size() == 12, "Eight keyposes and first four in-betweens survive engine interruption: " + board.status.text)
        var preserved: Dictionary = {}
        for path in board.paths:
            preserved[path] = FileAccess.get_sha256(path)
        await board._friendly_generate()
        for path in preserved:
            assert(FileAccess.get_sha256(path) == preserved[path], "Resume must not regenerate saved drawings")
    assert(board.universal_plan.get("semantic_analysis", false), board.status.text)
    assert(board.paths.size() == 17 and board.required_drawing_count == 17, board.status.text)
    assert(board.universal_quality["fidelity_verified"])
    assert(not board._has_current_review())
    assert(board.sources[0].get_width() <= 320, "UI keeps thumbnails instead of every full-resolution PNG")
    var worker: Node = board.universal_pipeline.worker
    assert(worker.local_model == "SIMULATED-vision-model")
    assert(not worker.use_opencl)
    assert(not worker._loopback("http://127.0.0.1.attacker.example:8080"))
    assert(not worker._loopback("http://192.168.1.20:8080"))
    assert(not worker._loopback("http://127.0.0.1:70000"))
    assert(not (await worker._local_request("https://invalid.example", "/generate"))["ok"])
    assert(not worker.decode_local_drawing('event: complete\ndata: {"type":"complete","width":512,"height":512,"channels":3,"image":"AA=="}\n\n')["ok"])
    assert(not worker.decode_local_drawing('event: error\ndata: {"type":"error","message":"SIMULATED"}\n\n')["ok"])
    board._show_drawing_review()
    assert(board.review_image.texture.get_width() == 512, "Enlarged review must load the original PNG")
    var hashes: Array = []
    for path in board.paths:
        hashes.append(FileAccess.get_sha256(path))
    var repair_index: int = board.paths.find(board.universal_folder.path_join("pose_0003.png"))
    assert(repair_index >= 0)
    board.review_index = repair_index
    board._review_choose(false)
    await board._regenerate_reviewed_drawing()
    assert(not board.accepted[repair_index] and not board._has_current_review())
    for i in range(board.paths.size()):
        assert((FileAccess.get_sha256(board.paths[i]) == hashes[i]) == (i != repair_index))
        board.review_index = i
        board._review_choose(true)
    board.review_check.set_pressed(true)
    assert(board._has_current_review(), board.status.text)
    board._save()
    assert(not FileAccess.get_file_as_string(board.SAVE).contains("test-local-secret"))
    var saved: Array[String] = board.paths.duplicate()
    board._load_saved()
    assert(board.local_mode.button_pressed and board.paths == saved)
    assert(board._universal_ready_for_review() and not board._has_current_review())
    board.queue_free()
    await process_frame
    print("LOCAL_STUDIO_TRANSPORT_OK: real loopback HTTP; SIMULATED inference; shared screen/pipeline, eight poses and nine in-betweens in three automatic batches, local budget two, bounded thumbnails/full PNG review, selective redo, consent, restore; no remote request or model inference")
    quit(0)
