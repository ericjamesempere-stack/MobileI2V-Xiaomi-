extends RefCounted
# Development-only learning loop: verified benchmark -> bounded experience ->
# quality-first strategy recommendation -> independent code-test decision.
# Never runs CI, changes source, deploys, or interprets simulated samples as device telemetry.
var experience: RefCounted = load("res://scripts/karma_agent_experience.gd").new()
var benchmark: RefCounted = load("res://scripts/karma_benchmark_agent.gd").new()
var code_tester: RefCounted = load("res://scripts/karma_code_test_agent.gd").new()

func learn(agent: String, strategy: String, samples: Array) -> Dictionary:
    var summary: Dictionary = benchmark.summarize(samples)
    if not summary.get("ok", false):
        return {"ok": false, "stage": "benchmark", "reason": summary.get("reason", "invalid_samples")}
    var metrics: Dictionary = {}
    for key in ["quality", "latency_ms", "energy_mj", "memory_mb"]:
        metrics[key] = summary[key]
    var result: Dictionary = experience.observe(agent, strategy, metrics)
    return {"ok": result.get("ok", false), "stage": "experience", "detail": result, "sample_count": samples.size()}

func choose(agent: String, strategies: Array, minimum_quality: float = 0.8) -> Dictionary:
    return experience.recommend(agent, strategies, minimum_quality)

func review_code_change(baseline_report: Dictionary, candidate_report: Dictionary) -> Dictionary:
    var result: Dictionary = code_tester.evaluate(baseline_report, candidate_report)
    return {"ok": result.get("ok", false), "decision": result.get("decision", "BLOCK"),
        "reason": result.get("reason", ""), "human_review_required": true, "may_deploy": false}

func export_experience() -> Dictionary:
    return experience.export_state()

func import_experience(state: Dictionary) -> Dictionary:
    return experience.import_state(state)
