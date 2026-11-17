extends RefCounted
# Development-only coordination of guard -> diagnosis -> recovery -> benchmark -> optimizer.
# This is an advisory chain, not a self-deploying runtime.
func evaluate_failure(agent: String, action: String, context: Dictionary, event: Dictionary, attempts: int, checkpoint: Dictionary, engines: Array) -> Dictionary:
    var guard: RefCounted = load("res://scripts/karma_guard_agent.gd").new()
    var access: Dictionary = guard.authorize(agent, action, context)
    if not access.get("ok", false):
        return {"ok": false, "stage": "guard", "detail": access}
    var diagnostic: Dictionary = load("res://scripts/karma_diagnostic_agent.gd").new().diagnose(event)
    diagnostic["failed_engine"] = str(event.get("engine", ""))
    var recovery: Dictionary = load("res://scripts/karma_recovery_agent.gd").new().plan(diagnostic, attempts, checkpoint, engines)
    return {"ok": recovery.get("ok", false), "stage": "recovery", "diagnostic": diagnostic, "recovery": recovery}

func evaluate_improvement(baseline_samples: Array, candidate_samples: Array, candidate_id: String) -> Dictionary:
    var benchmark: RefCounted = load("res://scripts/karma_benchmark_agent.gd").new()
    var baseline: Dictionary = benchmark.summarize(baseline_samples)
    var candidate: Dictionary = benchmark.summarize(candidate_samples)
    var recommendation: Dictionary = load("res://scripts/karma_optimizer_agent.gd").new().propose(baseline, candidate, candidate_id)
    return {"ok": recommendation.get("ok", false), "baseline": baseline, "candidate": candidate, "recommendation": recommendation, "requires_code_test": true, "may_deploy": false}
