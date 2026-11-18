extends SceneTree
# Offline contract tests for existing local/remote worker routing.
# Does not call cloud services or claim that inference works.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var board: Control = load("res://scripts/storyboard.gd").new()
    board.local_mode = CheckBox.new()
    board.remote_fallback = CheckBox.new()
    board.local_auth_input = LineEdit.new()
    board.remote_fallback.button_pressed = true

    board.local_mode.button_pressed = true
    board.local_auth_input.text = "local-test-key"
    var local_worker: Node = board._make_drawing_worker()
    assert(local_worker.get_script().resource_path == "res://scripts/local_studio_generator.gd")
    assert(local_worker.local_token == "local-test-key")
    assert(local_worker.vision_base == "http://127.0.0.1:8080")
    assert(local_worker.drawing_base == "http://127.0.0.1:8081")

    board.local_mode.button_pressed = false
    var remote_worker: Node = board._make_drawing_worker()
    assert(remote_worker.get_script().resource_path == "res://scripts/hf_studio_generator.gd")
    assert(not remote_worker.has_method("inspect_local_engines"))

    assert(board._may_use_remote_fallback({"ok": false, "http_status": 0, "network_result": 13}))
    assert(board._may_use_remote_fallback({"ok": false, "http_status": 503}))
    assert(not board._may_use_remote_fallback({"ok": true}))
    assert(not board._may_use_remote_fallback({"ok": false, "error_kind": "quota", "http_status": 429}))
    assert(not board._may_use_remote_fallback({"ok": false, "error_kind": "authentication", "http_status": 401}))
    assert(not board._may_use_remote_fallback({"ok": false, "error_kind": "safety"}))
    board.remote_fallback.button_pressed = false
    assert(not board._may_use_remote_fallback({"ok": false, "http_status": 503}))

    local_worker.free()
    remote_worker.free()
    board.local_mode.free()
    board.remote_fallback.free()
    board.local_auth_input.free()
    board.free()
    print("KARMA_ENGINE_ROUTING_OK")
    quit(0)
