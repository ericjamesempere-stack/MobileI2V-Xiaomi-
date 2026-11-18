extends SceneTree
# Adapter for the existing V60 code-test agent, invoked only by desktop Autopilot.

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1:
        quit(2)
        return
    var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    if not input is Dictionary:
        quit(2)
        return
    var guard: RefCounted = load("res://scripts/karma_guard_agent.gd").new()
    if not guard.authorize("code_test", "evaluate", {"session_valid": true}).get("ok", false):
        quit(2)
        return
    var reviewer: RefCounted = load("res://scripts/karma_code_test_agent.gd").new()
    var outcome: Dictionary = reviewer.review_candidate_checks(input)
    print("KARMA_CANDIDATE_REVIEW " + JSON.stringify(outcome))
    quit(0)
