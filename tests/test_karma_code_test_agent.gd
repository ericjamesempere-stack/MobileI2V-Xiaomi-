extends SceneTree
# Run with Godot: godot --headless --path . --script res://tests/test_karma_code_test_agent.gd
var errors: Array[String] = []
func check(value: bool, message: String) -> void:
    if not value:
        errors.append(message)

func report(commit_char: String, latency: float = 100.0, energy: float = 100.0, memory: float = 100.0, quality: float = 0.9) -> Dictionary:
    return {"commit_sha256": commit_char.repeat(64), "test_manifest_sha256": "c".repeat(64), "runner_verified": true,
        "suites": {"syntax": true, "unit": true, "integration": true, "regression": true, "security": true},
        "metrics": {"quality": quality, "latency_ms": latency, "energy_mj": energy, "memory_mb": memory}}

func _initialize() -> void:
    var agent: RefCounted = load("res://scripts/karma_code_test_agent.gd").new()
    var baseline: Dictionary = report("a")
    var faster: Dictionary = report("b", 80.0)
    check(agent.evaluate(baseline, faster).get("decision", "") == "RECOMMEND_REVIEW", "faster candidate not recommended")
    check(not agent.deployment_allowed(agent.evaluate(baseline, faster)), "agent self-deployed")
    check(agent.evaluate(baseline, report("b", 80.0, 100.0, 100.0, 0.8)).get("decision", "") == "REJECT", "quality regression accepted")
    check(agent.evaluate(baseline, report("b", 120.0)).get("decision", "") == "REJECT", "latency regression accepted")
    check(agent.evaluate(baseline, report("b", 80.0, 120.0)).get("decision", "") == "REJECT", "energy regression accepted")
    check(agent.evaluate(baseline, report("b", 80.0, 100.0, 120.0)).get("decision", "") == "REJECT", "memory regression accepted")
    var missing_suite: Dictionary = faster.duplicate(true)
    missing_suite["suites"]["security"] = false
    check(agent.evaluate(baseline, missing_suite).get("decision", "") == "BLOCK", "security failure accepted")
    var fake_runner: Dictionary = faster.duplicate(true)
    fake_runner["runner_verified"] = false
    check(agent.evaluate(baseline, fake_runner).get("decision", "") == "BLOCK", "unverified runner accepted")
    var changed_tests: Dictionary = faster.duplicate(true)
    changed_tests["test_manifest_sha256"] = "d".repeat(64)
    check(agent.evaluate(baseline, changed_tests).get("decision", "") == "BLOCK", "different tests accepted")
    check(agent.evaluate(baseline, baseline).get("decision", "") == "BLOCK", "identical commit accepted")
    check(agent.evaluate(baseline, report("b")).get("decision", "") == "HOLD", "no improvement accepted")
    if errors.is_empty():
        print("PASS karma_code_test_agent")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        quit(1)
