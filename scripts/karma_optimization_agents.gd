extends RefCounted
# Step 12 optimization agents: deterministic policies, no fake inference or
# unbounded autonomous code changes. They recommend settings; engines execute.
const AGENTS := ["resource", "vision", "image", "motion", "quality", "supervisor"]
const MAX_EDGE := 1024

func device_budget(free_mb: int, thermal_level: int, battery_percent: int, plugged_in: bool) -> Dictionary:
    # Conservative policy; actual limits must be measured on device.
    var constrained: bool = free_mb < 2048 or thermal_level >= 3 or (battery_percent < 20 and not plugged_in)
    var critical: bool = free_mb < 1024 or thermal_level >= 5 or battery_percent < 8
    return {"ok": not critical, "mode": "paused" if critical else ("economy" if constrained else "balanced"), "max_edge": 384 if critical else (512 if constrained else MAX_EDGE), "parallel_inference": 0 if critical else 1, "reason": "resource_limit" if critical else ("constrained_device" if constrained else "ready")}

func vision_plan(width: int, height: int, budget: Dictionary) -> Dictionary:
    if width <= 0 or height <= 0 or not budget.get("ok", false):
        return {"ok": false, "error": "invalid_image_or_budget"}
    var edge: int = mini(768, int(budget.get("max_edge", 512)))
    var factor: float = minf(1.0, float(edge) / float(maxi(width, height)))
    return {"ok": true, "width": maxi(1, roundi(width * factor)), "height": maxi(1, roundi(height * factor)), "preserve_original": true, "cache_key_required": true}

func image_plan(budget: Dictionary, fidelity: String = "normal") -> Dictionary:
    if not budget.get("ok", false):
        return {"ok": false, "error": "device_not_ready"}
    var edge: int = mini(MAX_EDGE, int(budget.get("max_edge", 512)))
    return {"ok": true, "target_edge": edge, "batch": 1, "precision": "quantized_if_supported", "fidelity": fidelity, "verify_output": true, "cloud_fallback": false}

func motion_plan(duration_seconds: float, fps: int, budget: Dictionary) -> Dictionary:
    if duration_seconds <= 0.0 or fps <= 0 or not budget.get("ok", false):
        return {"ok": false, "error": "invalid_motion_request"}
    var total: int = ceili(duration_seconds * float(fps))
    # Compute key poses sparsely, interpolate frames locally. This is a plan,
    # not proof that optical flow or a video model is installed.
    var stride: int = maxi(1, roundi(float(fps) / 3.0))
    return {"ok": true, "total_frames": total, "keyframes": ceili(float(total) / float(stride)) + 1, "interpolation": "local_if_available", "stride": stride, "requires_quality_gate": true}

func quality_gate(metrics: Dictionary) -> Dictionary:
    # Unknown metrics must never be interpreted as passing.
    for required in ["reference_similarity", "temporal_consistency", "artifact_score"]:
        if not metrics.has(required) or not (metrics[required] is float or metrics[required] is int):
            return {"ok": false, "error": "missing_quality_measurement", "metric": required}
    var accepted: bool = float(metrics["reference_similarity"]) >= 0.75 and float(metrics["temporal_consistency"]) >= 0.70 and float(metrics["artifact_score"]) <= 0.25
    return {"ok": accepted, "action": "accept" if accepted else "review_or_regenerate", "metrics": metrics.duplicate(true)}

func supervisor_plan(role: String, registry: RefCounted, requirements: Dictionary = {}) -> Dictionary:
    if registry == null or not registry.has_method("choose"):
        return {"ok": false, "error": "registry_unavailable"}
    var selection: Dictionary = registry.choose(role, requirements)
    if not selection.get("ok", false):
        return {"ok": false, "error": selection.get("error", "no_local_module"), "allow_cloud": false}
    return {"ok": true, "module": selection["key"], "allow_cloud": false, "require_quality_gate": true}
