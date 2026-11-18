extends RefCounted
# Fail-closed authorization and interface-contract guard. No network or code execution.
const ROLES := ["scenario", "pose", "image", "quality", "recovery", "video", "diagnostic", "benchmark", "optimizer", "code_test"]
const ALLOWED := {
    "scenario": ["plan"], "pose": ["pose"], "image": ["generate"], "quality": ["inspect"],
    "recovery": ["checkpoint", "resume"], "video": ["encode"], "diagnostic": ["diagnose"],
    "benchmark": ["measure"], "optimizer": ["propose"], "code_test": ["evaluate"]
}
func authorize(agent: String, action: String, context: Dictionary) -> Dictionary:
    if not ALLOWED.has(agent) or not ALLOWED[agent].has(action):
        return {"ok": false, "reason": "unauthorized_action"}
    if not bool(context.get("session_valid", false)):
        return {"ok": false, "reason": "invalid_session"}
    if action == "encode":
        if not bool(context.get("user_approved", false)) or str(context.get("approved_fingerprint", "")).is_empty() or context.get("approved_fingerprint") != context.get("current_fingerprint"):
            return {"ok": false, "reason": "approval_missing_or_stale"}
    if action == "generate" and not bool(context.get("engine_verified", false)):
        return {"ok": false, "reason": "unverified_engine"}
    return {"ok": true, "agent": agent, "action": action}
func validate_message(message: Dictionary) -> Dictionary:
    for key in ["agent", "action", "session_id", "request_id", "payload"]:
        if not message.has(key):
            return {"ok": false, "reason": "missing_" + key}
    if not message["payload"] is Dictionary:
        return {"ok": false, "reason": "invalid_payload"}
    if str(message["session_id"]).is_empty() or str(message["request_id"]).is_empty():
        return {"ok": false, "reason": "invalid_identifiers"}
    if message["payload"].has("token") or message["payload"].has("password"):
        return {"ok": false, "reason": "secrets_in_message"}
    return {"ok": true}
