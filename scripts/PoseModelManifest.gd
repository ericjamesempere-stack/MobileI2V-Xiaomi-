extends RefCounted
class_name PoseModelManifest

# Explicit runtime contract for an offline model. A manifest alone never
# indicates that inference is available or that image fidelity is guaranteed.
static func inspect(path: String) -> Dictionary:
    if not path.begins_with("user://") or not FileAccess.file_exists(path):
        return {"ok": false, "error": "manifest_missing"}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false, "error": "manifest_unreadable"}
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return {"ok": false, "error": "manifest_invalid"}
    var data: Dictionary = parsed
    for field in ["model_name", "model_path", "license", "backend", "reference_conditioning", "pose_conditioning"]:
        if not data.has(field):
            return {"ok": false, "error": "missing_field", "field": field}
    if str(data["model_name"]).strip_edges().is_empty() or str(data["license"]).strip_edges().is_empty():
        return {"ok": false, "error": "model_metadata_incomplete"}
    if not bool(data["reference_conditioning"]) or not bool(data["pose_conditioning"]):
        return {"ok": false, "error": "model_lacks_required_conditioning"}
    var model_path := str(data["model_path"])
    if not model_path.begins_with("user://") or not FileAccess.file_exists(model_path):
        return {"ok": false, "error": "model_weights_missing"}
    var backend := str(data["backend"])
    if backend != "onnxruntime" and backend != "mediapipe" and backend != "native":
        return {"ok": false, "error": "unsupported_backend"}
    return {
        "ok": true,
        "model_name": data["model_name"],
        "backend": backend,
        "model_path": model_path,
        "license": data["license"],
        "capabilities_declared": true,
        "inference_verified": false
    }
