extends SceneTree
# Opt-in GPU smoke test through the application's actual storyboard path.
# KARMA_TEST_REFERENCE must point to a synthetic PNG, never a private photo.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var reference: String = OS.get_environment("KARMA_TEST_REFERENCE")
    if reference.is_empty():
        push_error("Set KARMA_TEST_REFERENCE to a synthetic test image")
        quit(2)
        return
    var board: Control = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    board.imported_path = reference
    board.action_input.text = "Une banane anthropomorphe court, trébuche et tombe."
    board.duration_input.value = 4
    board.ai_drawings_count.value = 4
    board.drawing_style.select(1)
    await board._draw_remote_story()
    if board.last_ai_sequence_ok:
        assert(board.sources.size() == 4 and board.paths.size() == 4)
        assert(not board._has_current_review())
        for approved in board.accepted:
            assert(not approved)
    var evidence: Dictionary = {"complete": board.last_ai_sequence_ok, "frames": board.paths,
        "status": board.status.text, "engines": board.session_agent.state.get("engines", {}), "human_approved": false, "device_test": false}
    print("V54_REAL_STORY_RESULT " + JSON.stringify(evidence))
    board.queue_free()
    await process_frame
    quit(0 if evidence["complete"] else 1)
