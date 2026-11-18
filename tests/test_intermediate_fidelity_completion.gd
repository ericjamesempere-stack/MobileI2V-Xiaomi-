extends SceneTree

# Pure regression test: no model calls, quotas, or device access required.
func _initialize() -> void:
    var pipeline = load("res://scripts/universal_board_pipeline.gd")
    assert(pipeline != null)
    assert(pipeline._intermediate_review_complete({"ok": true, "fidelity_verified": true, "failed": [], "pending": []}))
    assert(not pipeline._intermediate_review_complete({"ok": true, "fidelity_verified": false, "failed": [], "pending": []}))
    assert(not pipeline._intermediate_review_complete({"ok": true, "fidelity_verified": true, "failed": ["scene_1"], "pending": []}))
    assert(not pipeline._intermediate_review_complete({"ok": true, "fidelity_verified": true, "failed": [], "pending": ["scene_2"]}))
    assert(not pipeline._intermediate_review_complete({"ok": false, "fidelity_verified": true, "failed": [], "pending": []}))
    print("INTERMEDIATE_FIDELITY_COMPLETION_GATE_OK")
    quit(0)
