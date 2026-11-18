extends RefCounted
# V60 development-only supervisor. Deliberately NOT wired to Android/UI until tests pass.
# Reports evidence, never invents model capability, image quality or physical device tests.
const AGENTS := ["scenario", "pose", "image", "quality", "recovery", "video"]
const STAGES := ["planned", "poses_ready", "images_ready", "quality_checked", "human_approved", "video_verified"]

func check_engine(report: Dictionary) -> Dictionary:
    var id: String = str(report.get("id", "")).strip_edges()
    if id.is_empty():
        return {"ok": false, "error": "engine_id_missing"}
    if not bool(report.get("reachable", false)):
        return {"ok": false, "engine": id, "error": "engine_unreachable"}
    if not bool(report.get("model_loaded", false)):
        return {"ok": false, "engine": id, "error": "model_not_loaded"}
    if not bool(report.get("image_inference_verified", false)):
        return {"ok": false, "engine": id, "error": "image_inference_not_verified"}
    if not bool(report.get("reference_conditioning_verified", false)):
        return {"ok": false, "engine": id, "error": "reference_conditioning_not_verified"}
    return {"ok": true, "engine": id}

func new_session(session_id: String) -> Dictionary:
    if session_id.strip_edges().is_empty():
        return {"ok": false, "error": "session_id_missing"}
    return {"ok": true, "id": session_id, "stage": "planned", "evidence": {}, "approved_fingerprint": "", "errors": []}

func advance(session: Dictionary, target: String, proof: Dictionary) -> Dictionary:
    if not bool(session.get("ok", false)):
        return {"ok": false, "error": "invalid_session"}
    var current: int = STAGES.find(str(session.get("stage", "")))
    var next: int = STAGES.find(target)
    if current < 0 or next != current + 1:
        return {"ok": false, "error": "invalid_stage_transition", "stage": session.get("stage", "")}
    if not bool(proof.get("ok", false)):
        return {"ok": false, "error": "proof_failed", "stage": session.get("stage", "")}
    match target:
        "poses_ready":
            if int(proof.get("pose_count", 0)) < 2:
                return {"ok": false, "error": "insufficient_poses"}
        "images_ready":
            if int(proof.get("real_image_count", 0)) < 2 or not bool(proof.get("pixel_files_verified", false)):
                return {"ok": false, "error": "real_images_not_verified"}
        "quality_checked":
            if not bool(proof.get("all_frames_checked", false)):
                return {"ok": false, "error": "quality_not_verified"}
        "human_approved":
            if str(proof.get("fingerprint", "")).is_empty() or not bool(proof.get("explicit_user_approval", false)):
                return {"ok": false, "error": "human_approval_missing"}
        "video_verified":
            if not bool(proof.get("mp4_decoded", false)) or str(proof.get("sha256", "")).length() != 64:
                return {"ok": false, "error": "video_not_verified"}
    var updated: Dictionary = session.duplicate(true)
    updated["stage"] = target
    var evidence: Dictionary = updated["evidence"]
    evidence[target] = proof.duplicate(true)
    if target == "human_approved":
        updated["approved_fingerprint"] = str(proof["fingerprint"])
    return updated

func may_export(session: Dictionary, current_fingerprint: String) -> Dictionary:
    if not bool(session.get("ok", false)) or str(session.get("stage", "")) != "human_approved":
        return {"ok": false, "error": "approval_required"}
    if current_fingerprint.is_empty() or current_fingerprint != str(session.get("approved_fingerprint", "")):
        return {"ok": false, "error": "approval_stale"}
    return {"ok": true}
