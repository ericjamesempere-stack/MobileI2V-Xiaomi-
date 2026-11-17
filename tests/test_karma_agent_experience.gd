extends SceneTree
# Run: godot --headless --path . --script res://tests/test_karma_agent_experience.gd
var failures: Array[String] = []
func expect(value: bool, label: String) -> void:
    if not value:
        failures.append(label)

func _initialize() -> void:
    var learner: RefCounted = load("res://scripts/karma_agent_experience.gd").new()
    expect(not learner.observe("image", "fast", {"quality": 0.9}).get("ok", false), "accepted incomplete metrics")
    expect(not learner.observe("image", "fast", {"quality": 1.5, "latency_ms": 10, "energy_mj": 10, "memory_mb": 10}).get("ok", false), "accepted invalid quality")
    expect(not learner.observe("image", "fast", {"quality": 0.9, "latency_ms": 10, "energy_mj": 10, "memory_mb": 10, "prompt": "private"}).get("ok", false), "accepted private fields")
    for i in range(3):
        expect(learner.observe("image", "fast", {"quality": 0.7, "latency_ms": 100, "energy_mj": 100, "memory_mb": 100}).get("ok", false), "fast observation failed")
        expect(learner.observe("image", "quality", {"quality": 0.95, "latency_ms": 500, "energy_mj": 200, "memory_mb": 100}).get("ok", false), "quality observation failed")
    var choice: Dictionary = learner.recommend("image", ["fast", "quality"], 0.8)
    expect(choice.get("ok", false) and choice.get("strategy", "") == "quality", "quality gate not respected")
    expect(not learner.recommend("image", ["fast"], 0.8).get("ok", false), "unqualified strategy accepted")
    var restored: RefCounted = load("res://scripts/karma_agent_experience.gd").new()
    expect(restored.import_state(learner.export_state()).get("ok", false), "restore failed")
    expect(restored.recommend("image", ["fast", "quality"]).get("strategy", "") == "quality", "restored experience differs")
    expect(not restored.import_state({"schema": 999, "records": {}}).get("ok", false), "wrong schema accepted")
    if failures.is_empty():
        print("PASS karma_agent_experience")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
