extends RefCounted
class_name ReferenceFidelityGate

# Explicit constraints for a reference-conditioned image generator.
# This gate checks prompt contracts, NOT visual similarity or image understanding.
const SUBJECT_TYPES := ["human", "animal", "object", "vehicle", "creature", "plant", "unknown"]

static func build_request(reference_path: String, description: String, subject_type: String, pose: Dictionary = {}) -> Dictionary:
    if not FileAccess.file_exists(reference_path):
        return {"ok": false, "error": "reference_missing"}
    if description.strip_edges().is_empty():
        return {"ok": false, "error": "description_missing"}
    if not SUBJECT_TYPES.has(subject_type):
        return {"ok": false, "error": "unsupported_subject_type"}
    var image := Image.new()
    if image.load(reference_path) != OK or image.is_empty():
        return {"ok": false, "error": "reference_unreadable"}
    var constraints := [
        "Preserve the original subject identity, silhouette, materials, colors and proportions.",
        "Preserve the scene and background unless the requested action explicitly changes them.",
        "Change only what is necessary for the requested action and camera motion.",
        "Do not add faces, arms, legs, clothing or human anatomy unless visible in the reference or explicitly requested.",
        "Use physically coherent poses and consistent scale across consecutive frames."
    ]
    if subject_type == "object" or subject_type == "plant" or subject_type == "vehicle":
        constraints.append("Do not anthropomorphize this subject unless explicitly requested.")
    return {
        "ok": true,
        "reference_original": reference_path,
        "subject_type": subject_type,
        "action": description.strip_edges(),
        "pose": pose.duplicate(true),
        "constraints": constraints,
        "reference_width": image.get_width(),
        "reference_height": image.get_height(),
        "identity_verified": false,
        "pose_verified": false,
        "requires_human_review": true
    }

static func approval_required(generated: Dictionary, user_approved: bool) -> Dictionary:
    if not generated.get("ok", false):
        return {"ok": false, "error": "generation_not_validated"}
    if not user_approved:
        return {"ok": false, "error": "approval_required"}
    return {"ok": true, "approved": true}
