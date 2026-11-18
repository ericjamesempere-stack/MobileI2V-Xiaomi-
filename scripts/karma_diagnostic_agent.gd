extends RefCounted
# Deterministic, explainable error classifier; no blind retries.
func diagnose(event: Dictionary) -> Dictionary:
    var status: int = int(event.get("http_status", 0))
    var code: String = str(event.get("error", "")).to_lower()
    if status == 429 or code.contains("quota") or code.contains("rate_limit"):
        return {"category": "quota", "recoverable": true, "action": "switch_verified_engine", "retry_same_engine": false}
    if status == 401 or status == 403:
        return {"category": "authorization", "recoverable": false, "action": "request_authorization"}
    if status >= 500 and status <= 599:
        return {"category": "service", "recoverable": true, "action": "checkpoint_then_verified_fallback"}
    if code.contains("photo") or code.contains("gallery") or code.contains("decode"):
        return {"category": "image_input", "recoverable": false, "action": "validate_image_bytes_and_permissions"}
    if code.contains("identity") or code.contains("fidelity"):
        return {"category": "quality", "recoverable": true, "action": "review_and_regenerate"}
    if code.contains("mp4") or code.contains("encoder"):
        return {"category": "video", "recoverable": false, "action": "preserve_frames_and_diagnose_encoder"}
    return {"category": "unknown", "recoverable": false, "action": "collect_sanitized_evidence"}
