extends RefCounted
# V60 standalone experience learner. Learns strategy preferences from measured
# outcomes; does not modify source code, train models or make network calls.
# Input must be sanitized metrics, never prompts, photos, tokens or file paths.
const SCHEMA := 1
const MAX_SAMPLES := 100
const MIN_SAMPLES := 3
const METRICS := ["quality", "latency_ms", "energy_mj", "memory_mb"]
var records: Dictionary = {}

func _valid_id(value: String) -> bool:
    if value.is_empty() or value.length() > 64:
        return false
    for i in range(value.length()):
        var c: String = value.substr(i, 1)
        if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and c != "_" and c != "-":
            return false
    return true

func observe(agent: String, strategy: String, metrics: Dictionary) -> Dictionary:
    if not _valid_id(agent) or not _valid_id(strategy):
        return {"ok": false, "error": "invalid_agent_or_strategy"}
    for field in METRICS:
        if not metrics.has(field) or not (metrics[field] is float or metrics[field] is int):
            return {"ok": false, "error": "missing_or_invalid_metric", "field": field}
        var number: float = float(metrics[field])
        if is_nan(number) or is_inf(number) or number < 0.0:
            return {"ok": false, "error": "invalid_metric_value", "field": field}
    if float(metrics["quality"]) > 1.0:
        return {"ok": false, "error": "quality_out_of_range"}
    if metrics.size() != METRICS.size():
        return {"ok": false, "error": "unexpected_fields"}
    var key: String = agent + "/" + strategy
    var samples: Array = records.get(key, [])
    samples.append(metrics.duplicate(true))
    if samples.size() > MAX_SAMPLES:
        samples.pop_front()
    records[key] = samples
    return {"ok": true, "samples": samples.size()}

func summarize(agent: String, strategy: String) -> Dictionary:
    var key: String = agent + "/" + strategy
    var samples: Array = records.get(key, [])
    if samples.is_empty():
        return {"ok": false, "error": "no_experience"}
    var sums: Dictionary = {"quality": 0.0, "latency_ms": 0.0, "energy_mj": 0.0, "memory_mb": 0.0}
    for sample in samples:
        for metric in METRICS:
            sums[metric] += float(sample[metric])
    for metric in METRICS:
        sums[metric] /= float(samples.size())
    sums["ok"] = true
    sums["samples"] = samples.size()
    sums["sufficient_evidence"] = samples.size() >= MIN_SAMPLES
    return sums

func recommend(agent: String, candidates: Array, minimum_quality: float = 0.8) -> Dictionary:
    if minimum_quality < 0.0 or minimum_quality > 1.0:
        return {"ok": false, "error": "invalid_quality_threshold"}
    var best: String = ""
    var best_score: float = -1.0
    for candidate in candidates:
        if not candidate is String:
            continue
        var stats: Dictionary = summarize(agent, candidate)
        if not stats.get("sufficient_evidence", false) or float(stats["quality"]) < minimum_quality:
            continue
        # Lower latency and energy are preferred only AFTER the quality gate.
        var score: float = float(stats["quality"]) / (1.0 + float(stats["latency_ms"]) / 1000.0 + float(stats["energy_mj"]) / 1000.0 + float(stats["memory_mb"]) / 1000.0)
        if score > best_score:
            best = candidate
            best_score = score
    if best.is_empty():
        return {"ok": false, "error": "no_verified_strategy", "requires_baseline": true}
    return {"ok": true, "strategy": best, "score": best_score}

func export_state() -> Dictionary:
    return {"schema": SCHEMA, "records": records.duplicate(true)}

func import_state(state: Dictionary) -> Dictionary:
    if int(state.get("schema", -1)) != SCHEMA or not state.get("records") is Dictionary:
        return {"ok": false, "error": "invalid_schema"}
    var previous: Dictionary = records
    records = {}
    var entries: Dictionary = state["records"]
    for key in entries:
        var parts: PackedStringArray = str(key).split("/")
        if parts.size() != 2 or not entries[key] is Array or entries[key].size() > MAX_SAMPLES:
            records = previous
            return {"ok": false, "error": "invalid_experience"}
        for metrics in entries[key]:
            if not metrics is Dictionary or not observe(parts[0], parts[1], metrics).get("ok", false):
                records = previous
                return {"ok": false, "error": "invalid_experience"}
    return {"ok": true, "strategies": records.size()}
