extends SceneTree

class FailingPipeline extends "res://scripts/universal_board_pipeline.gd":
    var calls: int = 0
    func _build_boards(_reference: Image, _story: String, _seconds: float, _style: String, _folder: String, _maximum_keyposes: int = 24) -> Dictionary:
        calls += 1
        return {"ok": false, "stage": "analysis", "detail": {"error": "synthetic provider failure"}}

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var story: String = "SYNTHETIC autopilot retry %d" % Time.get_ticks_usec()
    var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
    var node := FailingPipeline.new()
    root.add_child(node)
    for i in range(2):
        var result: Dictionary = await node.build_boards(image, story, 3.0, "original", "user://unused_budget_test")
        assert(result["stage"] == "analysis")
    assert(node.calls == 2)
    node.free()
    node = FailingPipeline.new()
    root.add_child(node)
    var blocked: Dictionary = await node.build_boards(image, story, 3.0, "original", "user://unused_budget_test")
    assert(blocked["stage"] == "supervision" and blocked["error"] == "autopilot_failure_budget_exhausted")
    assert(node.calls == 0)
    var changed: Dictionary = await node.build_boards(image, story + " changed", 3.0, "original", "user://unused_budget_test")
    assert(changed["stage"] == "analysis" and node.calls == 1)
    node.free()
    print("AUTOPILOT_PIPELINE_BUDGET_OK: actual production wrapper blocks third identical failure after restart")
    quit(0)
