extends SceneTree

# Static smoke test: load the real Android storyboard script, not a duplicate UI.
# Does not claim Android gallery, AI vision, or MP4 were exercised.
func _initialize() -> void:
    var script: Script = load("res://scripts/storyboard.gd")
    if script == null or not script.can_instantiate():
        push_error("storyboard script cannot instantiate")
        quit(1)
        return
    var board: Node = script.new()
    var required: Array[String] = [
        "_entries_for_universal_plan",
        "_universal_drawing_entries",
        "_draw_remote_story",
        "_friendly_generate",
        "_friendly_export",
        "_has_current_review"
    ]
    for method in required:
        if not board.has_method(method):
            push_error("missing storyboard wiring: " + method)
            board.free()
            quit(1)
            return
    var source: String = FileAccess.get_file_as_string("res://scripts/storyboard.gd")
    assert(source.contains("inspect_visual_change(reference, candidate_sources[i].get_image())"))
    assert(source.contains('universal_quality["visual_diagnostics"] = visual_warnings'))
    assert(source.contains('universal_quality["identity_verified"] = false'))
    assert(source.contains("if not visual_warnings.is_empty():"))
    assert(source.contains("anomalies visuelles potentielles"))
    assert(source.contains("func _explain_scene_failure(reason: String) -> String:"))
    assert(source.contains('kind in ["authentication", "safety", "quota", "rate_limit", "budget", "unsupported_scene_registry"]'))
    assert(source.contains('status_code in [400, 401, 402, 403, 409, 422, 429]'))
    assert(source.contains('detail.contains("quota")'))
    assert(source.contains('"missing_entities_or_actions":'))
    assert(source.contains("aucune scène n'a été inventée"))
    assert(source.contains("Moteur local indisponible. Bascule vers le moteur distant existant"))
    assert(source.contains('folder += "_remote_fallback"'))
    assert(source.contains("_configure_universal_pipeline(style_image, true)"))
    assert(source.contains('_configure_universal_pipeline(guide, universal_folder.ends_with("_remote_fallback"))'))
    assert(source.contains("_may_use_remote_fallback(result)"))
    board.free()
    print("PASS unified storyboard wiring: methods present")
    quit(0)
