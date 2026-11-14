extends SceneTree

# Deterministic visual smoke test of the actual articulated limb compositor.
# Synthetic cutout: no user photo or personal data is committed.
func _initialize() -> void:
    var storyboard_script = load("res://scripts/storyboard.gd")
    var compositor = storyboard_script.new()
    var width := 360
    var height := 480
    var bg := Color("25364a")
    var cutout := Image.create(width, height, false, Image.FORMAT_RGBA8)
    cutout.fill(Color.TRANSPARENT)
    # Torso and head remain fixed while four limbs move.
    for y in range(90, 290):
        for x in range(145, 215):
            cutout.set_pixel(x, y, Color("dce6ef"))
    for y in range(40, 105):
        for x in range(150, 210):
            if Vector2(float(x - 180), float(y - 72)).length() < 31.0:
                cutout.set_pixel(x, y, Color("e7b28e"))
    var joints = [
        [Vector2(150, 140), Vector2(100, 250), 18.0, 0.7],
        [Vector2(210, 140), Vector2(260, 250), 18.0, -0.7],
        [Vector2(163, 270), Vector2(140, 410), 22.0, -0.4],
        [Vector2(197, 270), Vector2(220, 410), 22.0, 0.4]
    ]
    var colors = [Color("dce6ef"), Color("dce6ef"), Color("c24c4c"), Color("c24c4c")]
    for j in range(joints.size()):
        var a: Vector2 = joints[j][0]
        var b: Vector2 = joints[j][1]
        var radius: float = joints[j][2]
        for y in range(height):
            for x in range(width):
                if compositor._joint_mask(float(x), float(y), a, b, radius) > 0.5:
                    cutout.set_pixel(x, y, colors[j])
    DirAccess.make_dir_recursive_absolute("user://visual_smoke")
    for frame in range(60):
        var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
        result.fill(bg)
        result.blend_rect(cutout, Rect2i(0, 0, width, height), Vector2i.ZERO)
        for joint in joints:
            compositor._erase_limb(result, joint[0], joint[1], joint[2], bg)
        for j in range(joints.size()):
            var joint = joints[j]
            var angle: float = joint[3] * sin(float(frame) * TAU / 30.0)
            compositor._limb_copy(result, cutout, joint[0], joint[1], angle, joint[2])
        var path := "user://visual_smoke/frame_%03d.png" % frame
        if result.save_png(path) != OK:
            push_error("Failed to save " + path)
            quit(1)
            return
    # Guard against a frozen animation or a broken alpha compositor.
    var first := Image.load_from_file("user://visual_smoke/frame_000.png")
    var quarter := Image.load_from_file("user://visual_smoke/frame_008.png")
    if first == null or quarter == null:
        push_error("Visual smoke frames could not be reloaded")
        quit(1)
        return
    var changed: int = 0
    for yy in range(0, height, 4):
        for xx in range(0, width, 4):
            var a: Color = first.get_pixel(xx, yy)
            var b: Color = quarter.get_pixel(xx, yy)
            if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
                changed += 1
    if changed < 30:
        push_error("Animation is frozen or nearly unchanged: %d changed sampled pixels" % changed)
        quit(1)
        return
    print("VISUAL_SMOKE_OK user://visual_smoke 60 frames changed_pixels=", changed)
    quit(0)
