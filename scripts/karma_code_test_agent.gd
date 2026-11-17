extends RefCounted
# KARMA ONE — controlled code testing agent, development-only.
# Compares trusted test reports. Never executes shell commands, changes source,
# deploys code or approves itself. An external CI runner supplies measured data.
const REQUIRED_SUITES := ["syntax", "unit", "integration", "regression", "security"]
const METRICS := ["quality", "latency_ms", "energy_mj", "memory_mb"]
const MAX_LATENCY_REGRESSION := 0.10
const MAX_ENERGY_REGRESSION := 0.10
const MAX_MEMORY_REGRESSION := 0.10
const QUALITY_TOLERANCE := 0.001

func _valid_digest(value: Variant) -> bool:
    if not value is String or value.length() != 64:
        return false
    for i in range(value.length()):
        var ch: String = value.substr(i, 1)
        if not ((ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "f")):
            return false
    return true

func _validate(report: Dictionary) -> Dictionary:
    if not _valid_digest(report.get("commit_sha256", "")):
        return {"ok": false, "error": "invalid_commit_digest"}
    if not _valid_digest(report.get("test_manifest_sha256", "")):
        return {"ok": false, "error": "invalid_test_manifest"}
    if not bool(report.get("runner_verified", false)):
        return {"ok": false, "error": "unverified_test_runner"}
    var suites: Variant = report.get("suites", {})
    if not suites is Dictionary:
        return {"ok": false, "error": "invalid_suites"}
    for suite in REQUIRED_SUITES:
        if not suites.has(suite) or not suites[suite] is bool or not suites[suite]:
            return {"ok": false, "error": "suite_not_passed", "suite": suite}
    var metrics: Variant = report.get("metrics", {})
    if not metrics is Dictionary or metrics.size() != METRICS.size():
        return {"ok": false, "error": "invalid_metrics"}
    for metric in METRICS:
        if not metrics.has(metric) or not (metrics[metric] is float or metrics[metric] is int):
            return {"ok": false, "error": "missing_metric", "metric": metric}
        var number: float = float(metrics[metric])
        if is_nan(number) or is_inf(number) or number < 0.0:
            return {"ok": false, "error": "invalid_metric", "metric": metric}
    if float(metrics["quality"]) > 1.0:
        return {"ok": false, "error": "invalid_quality"}
    return {"ok": true}

func evaluate(baseline: Dictionary, candidate: Dictionary) -> Dictionary:
    var old_check: Dictionary = _validate(baseline)
    if not old_check.get("ok", false):
        return {"ok": false, "decision": "BLOCK", "reason": "baseline_" + str(old_check.get("error", "invalid"))}
    var new_check: Dictionary = _validate(candidate)
    if not new_check.get("ok", false):
        return {"ok": false, "decision": "BLOCK", "reason": "candidate_" + str(new_check.get("error", "invalid")), "suite": new_check.get("suite", "")}
    if baseline["test_manifest_sha256"] != candidate["test_manifest_sha256"]:
        return {"ok": false, "decision": "BLOCK", "reason": "test_manifest_mismatch"}
    if baseline["commit_sha256"] == candidate["commit_sha256"]:
        return {"ok": false, "decision": "BLOCK", "reason": "same_commit"}
    var old_metrics: Dictionary = baseline["metrics"]
    var new_metrics: Dictionary = candidate["metrics"]
    if float(new_metrics["quality"]) + QUALITY_TOLERANCE < float(old_metrics["quality"]):
        return {"ok": false, "decision": "REJECT", "reason": "quality_regression"}
    var limits: Dictionary = {"latency_ms": MAX_LATENCY_REGRESSION, "energy_mj": MAX_ENERGY_REGRESSION, "memory_mb": MAX_MEMORY_REGRESSION}
    for metric in limits:
        var before: float = float(old_metrics[metric])
        var after: float = float(new_metrics[metric])
        if after > before * (1.0 + float(limits[metric])):
            return {"ok": false, "decision": "REJECT", "reason": metric + "_regression"}
    var improved: bool = float(new_metrics["quality"]) > float(old_metrics["quality"]) + QUALITY_TOLERANCE
    for metric in limits:
        improved = improved or float(new_metrics[metric]) < float(old_metrics[metric]) * 0.99
    if not improved:
        return {"ok": false, "decision": "HOLD", "reason": "no_measurable_improvement"}
    return {"ok": true, "decision": "RECOMMEND_REVIEW", "reason": "measured_improvement", "requires_human_approval": true, "candidate_commit": candidate["commit_sha256"]}

func deployment_allowed(_evaluation: Dictionary) -> bool:
    # Deliberate fail-closed design. Human-controlled CI deployment is separate.
    return false
