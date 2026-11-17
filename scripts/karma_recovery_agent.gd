extends RefCounted
# Recovery decisions only: never retries a failing endpoint automatically.
const MAX_ATTEMPTS := 2
func plan(failure: Dictionary, attempts: int, checkpoint: Dictionary, alternatives: Array) -> Dictionary:
    if attempts >= MAX_ATTEMPTS:
        return {"ok": false, "action": "stop", "reason": "attempt_budget_exhausted"}
    if not bool(checkpoint.get("verified", false)) or str(checkpoint.get("fingerprint", "")).is_empty():
        return {"ok": false, "action": "stop", "reason": "unverified_checkpoint"}
    if not bool(failure.get("recoverable", false)):
        return {"ok": false, "action": "stop", "reason": "not_recoverable"}
    for engine in alternatives:
        if engine is Dictionary and bool(engine.get("verified", false)) and bool(engine.get("available", false)) and str(engine.get("id", "")) != str(failure.get("failed_engine", "")):
            return {"ok": true, "action": "resume_from_checkpoint", "engine": engine["id"], "checkpoint_fingerprint": checkpoint["fingerprint"], "next_attempt": attempts + 1}
    return {"ok": false, "action": "pause", "reason": "no_verified_fallback"}
