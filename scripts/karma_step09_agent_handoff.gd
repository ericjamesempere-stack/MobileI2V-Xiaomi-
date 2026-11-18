extends RefCounted
# Step 9: one deterministic handoff contract for the existing agents.
# Does not pretend to provide a generative model or to run an Android service.
const SUPERVISOR = preload("res://scripts/karma_agent_supervisor.gd")
const STAGE_TO_AGENT := {
 "poses_ready": "motion",
 "images_ready": "redraw",
 "quality_checked": "qa",
 "human_approved": "approval",
 "video_verified": "video",
}
var supervisor: RefCounted = SUPERVISOR.new()
var session: Dictionary = {}

func begin(session_id: String) -> Dictionary:
 session = supervisor.new_session(session_id)
 return session.duplicate(true)

func handoff(target: String, evidence: Dictionary) -> Dictionary:
 if not STAGE_TO_AGENT.has(target):
  return {"ok": false, "error": "unknown_stage", "target": target}
 if not bool(session.get("ok", false)):
  return {"ok": false, "error": "session_not_started"}
 var result: Dictionary = supervisor.advance(session, target, evidence)
 if bool(result.get("ok", false)):
  session = result
 return {"ok": bool(result.get("ok", false)), "agent": STAGE_TO_AGENT[target], "result": result}

func export_permission(fingerprint: String) -> Dictionary:
 return supervisor.may_export(session, fingerprint)

func engine_permission(report: Dictionary) -> Dictionary:
 return supervisor.check_engine(report)

func snapshot() -> Dictionary:
 return session.duplicate(true)
