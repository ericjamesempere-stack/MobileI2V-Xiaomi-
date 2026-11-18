extends RefCounted
# Compare externally measured samples, never pretend that device telemetry exists.
const MIN_SAMPLES := 3
func summarize(samples: Array) -> Dictionary:
    if samples.size() < MIN_SAMPLES:
        return {"ok": false, "reason": "insufficient_samples"}
    var totals: Dictionary = {"quality": 0.0, "latency_ms": 0.0, "energy_mj": 0.0, "memory_mb": 0.0}
    for sample in samples:
        if not sample is Dictionary or not bool(sample.get("verified", false)):
            return {"ok": false, "reason": "unverified_sample"}
        for metric in totals:
            if not sample.has(metric) or not (sample[metric] is float or sample[metric] is int):
                return {"ok": false, "reason": "missing_metric_" + metric}
            var number: float = float(sample[metric])
            if is_nan(number) or is_inf(number) or number < 0.0:
                return {"ok": false, "reason": "invalid_metric_" + metric}
            totals[metric] += number
        if float(sample["quality"]) > 1.0:
            return {"ok": false, "reason": "quality_out_of_range"}
    for metric in totals:
        totals[metric] /= float(samples.size())
    totals["ok"] = true
    totals["samples"] = samples.size()
    return totals
