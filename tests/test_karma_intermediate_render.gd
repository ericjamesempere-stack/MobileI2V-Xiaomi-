extends SceneTree
# Offline integration: real PNG files, fake drawing provider. No AI inference claim.
class FakeDrawer:
    extends Node
    var calls: int = 0
    func redraw(source: Image, _prompt: String, _style: String, _previous: Image = null) -> Dictionary:
        calls += 1
        return {"ok": true, "image": source.duplicate()}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var folder: String = "user://test_intermediate_render"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
    for name in ["between_0000.png", "between_0000.json"]:
        var stale: String = folder.path_join(name)
        if FileAccess.file_exists(stale):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(stale))
    var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
    img.fill(Color.ORANGE)
    assert(img.save_png(folder.path_join("pose_0000.png")) == OK)
    img.fill(Color.BLUE)
    assert(img.save_png(folder.path_join("pose_0001.png")) == OK)
    var plan: Dictionary = {"ok": true, "intermediate_drawings": 1, "steps": [{"id": "a", "intermediate_drawings": 1}], "boards": [
        {"id": "pose_0000", "index": 0, "step_id": "a", "video_frame": 0, "pose": "initial", "actor_ids": ["fruit"], "object_ids": []},
        {"id": "pose_0001", "index": 1, "step_id": "a", "video_frame": 10, "pose": "final", "actor_ids": ["fruit"], "object_ids": []}
    ]}
    var drawer := FakeDrawer.new()
    root.add_child(drawer)
    var agent: RefCounted = load("res://scripts/karma_intermediate_agent.gd").new()
    var first: Dictionary = await agent.render_pending(plan, folder, drawer, "original", 1)
    assert(first.get("ok", false) and first["generated"] == 1)
    assert(drawer.calls == 1)
    var task: Dictionary = first["results"][0]
    assert(task["status"] == "candidate_requires_review" and not task["human_approved"])
    assert(FileAccess.file_exists(task["image_path"]))
    var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("between_0000.json")))
    assert(meta is Dictionary and not meta["human_approved"] and not meta["identity_verified"])
    var second: Dictionary = await agent.render_pending(plan, folder, drawer, "original", 1)
    assert(second.get("ok", false) and second["generated"] == 0)
    assert(drawer.calls == 1)
    assert(second["results"][0]["status"] == "candidate_cached")
    assert(not second["ready_for_animation"])
    print("V54_INTERMEDIATE_RENDER_CANDIDATES_OK")
    quit(0)
