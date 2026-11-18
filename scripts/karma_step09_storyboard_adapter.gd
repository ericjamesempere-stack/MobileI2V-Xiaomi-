extends RefCounted
# Step 9D: evidence adapter between actual image output and the existing supervisor.
# No image quality or user approval is inferred from successful network requests.
const HANDOFF = preload("res://scripts/karma_step09_agent_handoff.gd")
var gate: RefCounted = HANDOFF.new()

func begin(job_id: String) -> Dictionary:
 return gate.begin(job_id)

func accept_pose_plan(pose_count: int, plan_verified: bool) -> Dictionary:
 return gate.handoff("poses_ready", {"ok": plan_verified, "pose_count": pose_count})

func accept_generated_frames(frames: Array, source: String) -> Dictionary:
 if source.strip_edges().is_empty():
  return {"ok": false, "error": "missing_generation_source"}
 var valid: int = 0
 for frame in frames:
  if not frame is Image or frame.is_empty() or frame.get_width() < 16 or frame.get_height() < 16:
   return {"ok": false, "error": "invalid_frame_pixels", "valid": valid}
  valid += 1
 return gate.handoff("images_ready", {"ok": valid >= 2, "real_image_count": valid, "pixel_files_verified": valid >= 2, "source": source})

func accept_quality_review(all_frames_checked: bool, accepted: bool, report: Dictionary = {}) -> Dictionary:
 if not accepted:
  return {"ok": false, "error": "quality_rejected"}
 return gate.handoff("quality_checked", {"ok": accepted, "all_frames_checked": all_frames_checked, "report": report})

func approve(fingerprint: String, explicit_user_approval: bool) -> Dictionary:
 return gate.handoff("human_approved", {"ok": explicit_user_approval, "fingerprint": fingerprint, "explicit_user_approval": explicit_user_approval})

func may_export(fingerprint: String) -> Dictionary:
 return gate.export_permission(fingerprint)

func state() -> Dictionary:
 return gate.snapshot()
