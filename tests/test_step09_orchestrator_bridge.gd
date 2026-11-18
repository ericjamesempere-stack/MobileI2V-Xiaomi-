extends SceneTree
const ORCHESTRATOR = preload("res://scripts/karma_one_orchestrator.gd")
func _initialize() -> void:
 var node = ORCHESTRATOR.new()
 assert(not node.may_export_approved("approved").get("ok", false))
 assert(node.start_agent_session("step09c").get("ok", false))
 assert(not node.submit_agent_evidence("images_ready", {"ok": true, "real_image_count": 8, "pixel_files_verified": true}).get("ok", false))
 assert(node.submit_agent_evidence("poses_ready", {"ok": true, "pose_count": 8}).get("ok", false))
 assert(node.agent_status().get("stage", "") == "poses_ready")
 assert(not node.may_export_approved("approved").get("ok", false))
 print("STEP09_ORCHESTRATOR_BRIDGE_PASS")
 quit(0)
