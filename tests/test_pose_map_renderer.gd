extends SceneTree

func _initialize() -> void:
    var folder := "user://pose_renderer_test"
    var a := {"action": "run", "pose_phase": 0.0, "action_progress": 0.2}
    var b := {"action": "run", "pose_phase": 0.25, "action_progress": 0.4}
    var one := PoseMapRenderer.render(a, folder + "/a.png", 256, 256)
    var two := PoseMapRenderer.render(b, folder + "/b.png", 256, 256)
    if not one.get("ok", false) or not two.get("ok", false):
        push_error("Pose map PNG rendering failed")
        quit(1)
        return
    var image_a := Image.new()
    var image_b := Image.new()
    if image_a.load(one["path"]) != OK or image_b.load(two["path"]) != OK:
        push_error("Pose maps are unreadable")
        quit(1)
        return
    if image_a.get_size() != Vector2i(256, 256) or image_b.get_size() != Vector2i(256, 256):
        push_error("Unexpected pose map dimensions")
        quit(1)
        return
    if FileAccess.get_sha256(one["path"]) == FileAccess.get_sha256(two["path"]):
        push_error("Different motion phases produced identical poses")
        quit(1)
        return
    print("Pose map generation OK: distinct 256x256 skeletons")
    quit(0)
