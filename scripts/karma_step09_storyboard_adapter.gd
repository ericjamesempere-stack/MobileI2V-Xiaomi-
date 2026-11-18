extends RefCounted
# Step 9D: evidence adapter between actual image output and the existing supervisor.
# No image quality or user approval is inferred from successful network requests.
const HANDOFF = preload("res://scripts/karma_step09_agent_handoff.gd")
var gate: RefCounted = HANDOFF.new()

func begin(job_id: String) -> Dictionary:
 return gate.begin(job_id)

func accept_pose_plan(pose_count: int, plan_verified: bool) -> Dictionary:
 return gate.handoff("poses_ready", {"ok": plan_verified, "pose_count": pose_count})

func accept_generated_frames(frames: Array, saved_png_paths: Array, source: String) -> Dictionary:
 if source.strip_edges().is_empty():
  return {"ok": false, "error": "missing_generation_source"}
 if saved_png_paths.size() != frames.size():
  return {"ok": false, "error": "saved_frame_count_mismatch"}
 var valid: int = 0
 for frame in frames:
  if not frame is Image or frame.is_empty() or frame.get_width() < 16 or frame.get_height() < 16:
   return {"ok": false, "error": "invalid_frame_pixels", "valid": valid}
  var path: String = str(saved_png_paths[valid])
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path).is_empty():
   return {"ok": false, "error": "saved_frame_missing_or_unreadable", "index": valid}
  var disk_image := Image.new()
  if disk_image.load(path) != OK or disk_image.is_empty():
   return {"ok": false, "error": "saved_frame_invalid", "index": valid}
  if disk_image.get_width() != frame.get_width() or disk_image.get_height() != frame.get_height():
   return {"ok": false, "error": "saved_frame_dimensions_mismatch", "index": valid}
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
