extends SceneTree
# Run: godot --headless --path . --script res://tests/test_karma_agent_learning_lab.gd
var failures: Array[String] = []
func check(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
func sample(q: float, t: float) -> Dictionary:
    return {"verified": true, "quality": q, "latency_ms": t, "energy_mj": 100.0, "memory_mb": 100.0}
func report(digest: String, latency: float) -> Dictionary:
    return {"commit_sha256": digest.repeat(64), "test_manifest_sha256": "c".repeat(64), "runner_verified": true,
        "suites": {"syntax": true, "unit": true, "integration": true, "regression": true, "security": true},
        "metrics": {"quality": 0.9, "latency_ms": latency, "energy_mj": 100.0, "memory_mb": 100.0}}
func _initialize() -> void:
    var lab: RefCounted = load("res://scripts/karma_agent_learning_lab.gd").new()
    check(not lab.learn("image", "fast", [sample(0.9, 50.0)]).get("ok", false), "accepted insufficient samples")
    check(not lab.choose("image", ["fast"]).get("ok", false), "recommended without experience")
    for n in range(3):
        var fast: Array = [sample(0.7, 50.0), sample(0.7, 50.0), sample(0.7, 50.0)]
        var quality: Array = [sample(0.95, 100.0), sample(0.95, 100.0), sample(0.95, 100.0)]
        check(lab.learn("image", "fast", fast).get("ok", false), "failed fast observation")
        check(lab.learn("image", "quality", quality).get("ok", false), "failed quality observation")
    check(lab.choose("image", ["fast", "quality"]).get("strategy", "") == "quality", "quality-first choice failed")
    var snapshot: Dictionary = lab.export_experience()
    var restored: RefCounted = load("res://scripts/karma_agent_learning_lab.gd").new()
    check(restored.import_experience(snapshot).get("ok", false), "experience restoration failed")
    check(restored.choose("image", ["fast", "quality"]).get("strategy", "") == "quality", "restored decision changed")
    var review: Dictionary = lab.review_code_change(report("a", 100.0), report("b", 80.0))
    check(review.get("decision", "") == "RECOMMEND_REVIEW", "valid improvement not reviewed")
    check(not review.get("may_deploy", true), "automatic deployment enabled")
    check(lab.review_code_change(report("a", 100.0), report("b", 120.0)).get("decision", "") == "REJECT", "regression accepted")
    if failures.is_empty():
        print("PASS karma_agent_learning_lab")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
