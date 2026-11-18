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
        "_friendly_create",
        "_friendly_export",
        "_has_current_review"
    ]
    for method in required:
        if not board.has_method(method):
            push_error("missing storyboard wiring: " + method)
            board.free()
            quit(1)
            return
    board.free()
    print("PASS unified storyboard wiring: methods present")
    quit(0)
