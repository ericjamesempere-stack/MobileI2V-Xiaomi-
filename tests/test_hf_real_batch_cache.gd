extends SceneTree
# Uses the opt-in real test's generated cache. No GPU call is permitted.
# Run only after tools/test_v54_real_story.gd has produced four drawings.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var reference: String = OS.get_environment("KARMA_TEST_REFERENCE")
    assert(not reference.is_empty())
    var board: Control = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    board.imported_path = reference
    board.action_input.text = "Une banane anthropomorphe court, trébuche et tombe."
    board.duration_input.value = 4
    board.ai_drawings_count.value = 4
    board.drawing_style.select(1)
    # Require matching cached files before entering the application generator.
    var image: Image = load("res://scripts/android_image_reader.gd").read_image(reference)
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(image.get_data())
    var digest: String = hash.finish().hex_encode()
    var revision: String = load("res://scripts/board_generation_plan.gd").REMOTE_BRIEF_VERSION
    var key: String = (digest + board.action_input.text + "cartoon" + str(4) + str(4.0) + revision).sha256_text().substr(0, 24)
    var folder: String = "user://projects/hf_" + key
    var hashes: Array[String] = []
    for index in range(4):
        var path: String = folder.path_join("frame_%04d.png" % index)
        assert(FileAccess.file_exists(path))
        hashes.append(FileAccess.get_sha256(path))
    await board._draw_remote_story()
    assert(board.last_ai_sequence_ok and board.paths.size() == 4)
    assert(board.session_agent.state["engines"].is_empty())
    assert(not board._has_current_review())
    for index in range(4):
        assert(FileAccess.get_sha256(board.paths[index]) == hashes[index])
        assert(not board.accepted[index])
    board.queue_free()
    await process_frame
    print("HF_REAL_BATCH_CACHE_OK: four real PNGs reused unchanged; no inference; human approval still required")
    quit(0)
