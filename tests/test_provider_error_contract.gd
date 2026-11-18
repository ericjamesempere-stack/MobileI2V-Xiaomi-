extends SceneTree
# Pure provider-error contract tests: no external requests, no GPU use.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var worker: Node = load("res://scripts/hf_studio_generator.gd").new()
    root.add_child(worker)
    var cases: Array = [
        [429, "quota"], [401, "authentication"], [403, "authentication"],
        [402, "budget"], [400, "invalid_request"], [409, "invalid_request"],
        [422, "invalid_request"], [500, "transport"], [503, "transport"],
        [0, "transport"]
    ]
    for row in cases:
        var result: Dictionary = worker._http_failure(int(row[0]), 13)
        assert(not result["ok"])
        assert(result["http_status"] == int(row[0]))
        assert(result["network_result"] == 13)
        assert(result["error_kind"] == row[1])
    worker.queue_free()
    print("KARMA_PROVIDER_ERRORS_OK")
    quit(0)
