extends SceneTree

class FailingPipeline extends "res://scripts/universal_board_pipeline.gd":
    var calls: int = 0
    func _build_boards(_reference: Image, _story: String, _seconds: float, _style: String, _folder: String, _maximum_keyposes: int = 24) -> Dictionary:
        calls += 1
        return {"ok": false, "stage": "analysis", "detail": {"error": "synthetic provider failure"}}

class BudgetFixtureWorker extends Node:
    var local_model: String = ""
    var style_reference: Image = null
    func vision_provider_id() -> String:
        return "budget-fixture-provider"
    func inference_context_id() -> String:
        return "budget-fixture:" + local_model

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var story: String = "SYNTHETIC autopilot retry %d" % Time.get_ticks_usec()
    var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
    var node := FailingPipeline.new()
    node.worker = BudgetFixtureWorker.new()
    root.add_child(node)
    for i in range(2):
        var result: Dictionary = await node.build_boards(image, story, 3.0, "original", "user://unused_budget_test")
        assert(result["stage"] == "analysis")
    assert(node.calls == 2)
    node.free()
    node = FailingPipeline.new()
    node.worker = BudgetFixtureWorker.new()
    root.add_child(node)
    var blocked: Dictionary = await node.build_boards(image, story, 3.0, "original", "user://unused_budget_test")
    assert(blocked["stage"] == "supervision" and blocked["error"] == "autopilot_failure_budget_exhausted")
    assert(node.calls == 0)
    var changed: Dictionary = await node.build_boards(image, story + " changed", 3.0, "original", "user://unused_budget_test")
    assert(changed["stage"] == "analysis" and node.calls == 1)
    node.free()
    node = FailingPipeline.new()
    node.local_inference = true
    node.worker = BudgetFixtureWorker.new()
    root.add_child(node)
    node.worker.local_model = "fixture-model-a"
    var stable_provider: String = node.worker.vision_provider_id()
    for i in range(2):
        var failed: Dictionary = await node.build_boards(image, story, 3.0, "original", "user://unused_local_budget_test")
        assert(failed["stage"] == "analysis")
    var local_blocked: Dictionary = await node.build_boards(image, story, 3.0, "original", "user://unused_local_budget_test")
    assert(local_blocked["stage"] == "supervision" and node.calls == 2)
    node.worker.local_model = "fixture-model-b"
    assert(node.worker.vision_provider_id() == stable_provider, "Existing drawing review provenance remains stable")
    var new_model: Dictionary = await node.build_boards(image, story, 3.0, "original", "user://unused_local_budget_test")
    assert(new_model["stage"] == "analysis" and node.calls == 3, "A genuinely different active model has its own retry budget")
    node.free()
    print("AUTOPILOT_PIPELINE_BUDGET_OK: actual production wrapper blocks third identical failure after restart")
    quit(0)
