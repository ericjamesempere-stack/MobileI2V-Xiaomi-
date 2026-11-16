extends RefCounted
# Specialized deterministic modules, not independent LLMs. Human review is mandatory.
var state: Dictionary = {}
var folder_path: String = ""
func begin(story: String, duration: float, count: int) -> Dictionary:
    var preparation: Dictionary = load("res://scripts/karma_one_agents.gd").new().plan(story, duration, count)
    if not preparation.get("ok", false):
        return preparation
    state = {"version": 1, "story": story, "duration": duration, "count": count, "frames": {}, "identity_verified": false,
        "agents": {"scenario": "done", "pose": "timed_instructions_ready", "image": "running", "quality": "pending", "recovery": "saving", "video": "waiting_for_user"}}
    return {"ok": true, "motion": preparation["motion"]}
func inspect_frame(image: Image, previous: Image = null) -> Dictionary:
    if image == null or image.is_empty():
        return {"ok": false, "issues": ["missing_or_empty_image"]}
    var result: Dictionary = load("res://scripts/drawing_quality_gate.gd").new().inspect(image, previous)
    if image != null and (image.get_width() < 512 or image.get_height() < 512):
        result["ok"] = false
        result["issues"].append("resolution_too_small")
    return result
func record_frame(index: int, path: String, quality: Dictionary) -> void:
    state["frames"][str(index)] = {"path": path, "technical_quality": quality, "human_approved": false}
func finish_drawings(error: String) -> void:
    state["agents"]["image"] = "done" if error.is_empty() else "paused"
    state["agents"]["quality"] = "technical_checks_only"
    state["agents"]["recovery"] = "saved"
    state["agents"]["video"] = "waiting_for_user"
    state["error"] = error
func save(folder: String) -> bool:
    folder_path = folder
    var target: String = folder.path_join("karma_agents.json")
    var file := FileAccess.open(target + ".part", FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(state, "  "))
    file.close()
    return DirAccess.rename_absolute(target + ".part", target) == OK


func record_user_approval(fingerprint: String) -> void:
    state["human_review"] = {"approved": true, "fingerprint": fingerprint, "time": Time.get_unix_time_from_system()}
    state["agents"]["video"] = "encoding_after_user_approval"
    for frame in state.get("frames", {}).values():
        frame["human_approved"] = true
    if not folder_path.is_empty():
        save(folder_path)

func record_video_result(output: String) -> void:
    # A returned path is not proof that an MP4 was encoded successfully.
    var exists: bool = not output.is_empty() and FileAccess.file_exists(output)
    var valid_mp4: bool = exists and output.to_lower().ends_with(".mp4")
    var size_ok: bool = false
    if valid_mp4:
        var file := FileAccess.open(output, FileAccess.READ)
        if file != null:
            if file.get_length() > 1024:
                # MP4 ISO BMFF starts with a box size followed by the ftyp brand.
                file.seek(4)
                size_ok = file.get_buffer(4).get_string_from_ascii() == "ftyp"
            file.close()
    state["agents"]["video"] = "encoded_native" if size_ok else "failed"
    state["video_output"] = output if size_ok else ""
    if not size_ok:
        state["video_error"] = "MP4 missing, empty, or not confirmed on disk"
    if not folder_path.is_empty():
        save(folder_path)
