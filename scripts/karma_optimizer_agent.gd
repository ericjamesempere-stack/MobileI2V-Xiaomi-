extends RefCounted
# Proposes safe improvements; code-test agent and human CI own acceptance.
func propose(baseline: Dictionary, candidate: Dictionary, candidate_id: String) -> Dictionary:
    if candidate_id.is_empty() or not bool(baseline.get("ok", false)) or not bool(candidate.get("ok", false)):
        return {"ok": false, "reason": "missing_verified_benchmarks"}
    if float(candidate.get("quality", -1.0)) < float(baseline.get("quality", 0.0)):
        return {"ok": false, "reason": "quality_regression"}
    var changes: Array[String] = []
    for metric in ["latency_ms", "energy_mj", "memory_mb"]:
        var old_value: float = float(baseline.get(metric, 0.0))
        var new_value: float = float(candidate.get(metric, 0.0))
        if old_value <= 0.0:
            return {"ok": false, "reason": "invalid_baseline_" + metric}
        if new_value > old_value * 1.1:
            return {"ok": false, "reason": "regression_" + metric}
        if new_value < old_value * 0.99:
            changes.append(metric)
    if changes.is_empty() and float(candidate["quality"]) <= float(baseline["quality"]):
        return {"ok": false, "reason": "no_measured_gain"}
    return {"ok": true, "proposal": candidate_id, "improved": changes, "requires_code_tests": true, "requires_approval": true, "may_deploy": false}
