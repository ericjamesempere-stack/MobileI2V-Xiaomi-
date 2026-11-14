extends RefCounted
# Offline storyboard-to-keyframes pipeline. No neural redraw is performed.
const Planner = preload("res://scripts/board_generation_plan.gd")
const Renderer = preload("res://scripts/reference_guided_cartoon_renderer.gd")
const Quality = preload("res://scripts/drawing_quality_gate.gd")
const MAX_FRAMES_PER_BATCH := 48

func prepare(story: String, reference: Image, duration: float, fps: int = 30) -> Dictionary:
    if reference == null or reference.is_empty():
        return {"ok": false, "reason": "missing_reference"}
    if duration <= 0.0 or fps < 1:
        return {"ok": false, "reason": "invalid_timing"}
    var plan: Dictionary = Planner.new().make_plan(story, ["private_reference_in_memory"], duration, fps)
    if plan["boards"].is_empty():
        return {"ok": false, "reason": "no_supported_actions", "plan": plan}
    return {"ok": true, "plan": plan, "method": "offline_procedural_reference_palette", "generative_redraw": false}

func render_batch(prepared: Dictionary, reference: Image, start_index: int = 0, count: int = 12, size: Vector2i = Vector2i(360, 480)) -> Dictionary:
    if not prepared.get("ok", false):
        return {"ok": false, "reason": "invalid_plan"}
    if reference == null or reference.is_empty() or size.x < 16 or size.y < 16:
        return {"ok": false, "reason": "invalid_reference_or_size"}
    var boards: Array = prepared["plan"]["boards"]
    var begin: int = clampi(start_index, 0, boards.size())
    var end: int = mini(boards.size(), begin + clampi(count, 1, MAX_FRAMES_PER_BATCH))
    var renderer: RefCounted = Renderer.new()
    var quality: RefCounted = Quality.new()
    var frames: Array[Image] = []
    var metadata: Array = []
    var previous: Image = null
    for i in range(begin, end):
        var board: Dictionary = boards[i]
        var action: String = str(board["action"])
        var first: int = i
        while first > 0 and str(boards[first - 1]["action"]) == action and int(boards[first - 1]["scene"]) == int(board["scene"]):
            first -= 1
        var last: int = i
        while last + 1 < boards.size() and str(boards[last + 1]["action"]) == action and int(boards[last + 1]["scene"]) == int(board["scene"]):
            last += 1
        var phase: float = float(i - first) / float(maxi(1, last - first))
        var result: Dictionary = renderer.render_with_reference(reference, str(board["story_context"]), phase, size, action)
        if not result.get("ok", false):
            return {"ok": false, "reason": result.get("reason", "render_failed"), "failed_board": i}
        var frame: Image = result["image"]
        var check: Dictionary = quality.inspect(frame, previous)
        frames.append(frame)
        metadata.append({"board_id": board["id"], "action": action, "phase": phase, "quality": check, "generative_redraw": false})
        previous = frame
    return {"ok": true, "frames": frames, "metadata": metadata, "next_index": end, "complete": end >= boards.size(), "generative_redraw": false, "identity_verified": false}
