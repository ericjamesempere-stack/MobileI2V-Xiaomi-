extends SceneTree
# Run: godot --headless --path . --script res://tests/test_karma_control_lab.gd
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
func sample(q: float, t: float, e: float, m: float) -> Dictionary:
    return {"verified": true, "quality": q, "latency_ms": t, "energy_mj": e, "memory_mb": m}
func _initialize() -> void:
    var guard: RefCounted = load("res://scripts/karma_guard_agent.gd").new()
    var diag: RefCounted = load("res://scripts/karma_diagnostic_agent.gd").new()
    var recovery: RefCounted = load("res://scripts/karma_recovery_agent.gd").new()
    var bench: RefCounted = load("res://scripts/karma_benchmark_agent.gd").new()
    var optimizer: RefCounted = load("res://scripts/karma_optimizer_agent.gd").new()
    var lab: RefCounted = load("res://scripts/karma_agent_control_lab.gd").new()
    check(not guard.authorize("code_test", "merge_protected_branch", {"session_valid": true}).get("ok", false), "protected merge allowed")
    check(not guard.authorize("image", "encode", {"session_valid": true}).get("ok", false), "image agent can encode")
    check(not guard.authorize("video", "encode", {"session_valid": true, "user_approved": true, "approved_fingerprint": "a", "current_fingerprint": "b"}).get("ok", false), "stale approval accepted")
    check(guard.authorize("video", "encode", {"session_valid": true, "user_approved": true, "approved_fingerprint": "a", "current_fingerprint": "a"}).get("ok", false), "valid approval blocked")
    check(not guard.authorize("image", "generate", {"session_valid": true}).get("ok", false), "unverified engine accepted")
    check(not guard.validate_message({"agent": "image", "action": "generate", "session_id": "1", "request_id": "2", "payload": {"token": "secret"}}).get("ok", false), "secret accepted")
    check(diag.diagnose({"http_status": 429}).get("category", "") == "quota", "quota undetected")
    check(diag.diagnose({"error": "gallery decode failed"}).get("category", "") == "image_input", "gallery undetected")
    var failure: Dictionary = diag.diagnose({"http_status": 503})
    failure["failed_engine"] = "primary"
    var checkpoint: Dictionary = {"verified": true, "fingerprint": "hash"}
    var alternatives: Array = [{"id": "primary", "verified": true, "available": true}, {"id": "secondary", "verified": true, "available": true}]
    check(recovery.plan(failure, 0, checkpoint, alternatives).get("engine", "") == "secondary", "fallback not selected")
    check(not recovery.plan(failure, 2, checkpoint, alternatives).get("ok", false), "retry budget ignored")
    check(not recovery.plan(failure, 0, {}, alternatives).get("ok", false), "checkpoint missing accepted")
    var before: Array = [sample(0.9, 100, 100, 100), sample(0.9, 100, 100, 100), sample(0.9, 100, 100, 100)]
    var after: Array = [sample(0.92, 80, 80, 90), sample(0.92, 80, 80, 90), sample(0.92, 80, 80, 90)]
    check(not bench.summarize(before.slice(0, 2)).get("ok", false), "insufficient benchmark accepted")
    check(optimizer.propose(bench.summarize(before), bench.summarize(after), "candidate").get("ok", false), "valid improvement rejected")
    check(not optimizer.propose(bench.summarize(before), bench.summarize(before), "candidate").get("ok", false), "no gain accepted")
    check(lab.evaluate_improvement(before, after, "candidate").get("ok", false), "lab improvement failed")
    check(not lab.evaluate_improvement(before, after, "candidate").get("may_deploy", true), "lab self deployment allowed")
    check(lab.evaluate_failure("image", "generate", {"session_valid": true, "engine_verified": true}, {"http_status": 503, "engine": "primary"}, 0, checkpoint, alternatives).get("ok", false), "lab recovery failed")
    check(not lab.evaluate_failure("image", "generate", {"session_valid": true, "engine_verified": false}, {"http_status": 503, "engine": "primary"}, 0, checkpoint, alternatives).get("ok", false), "guard bypassed")
    if failures.is_empty():
        print("PASS karma_control_lab")
        quit(0)
    else:
        for failure_message in failures:
            push_error(failure_message)
        quit(1)
