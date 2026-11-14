extends SceneTree

func _initialize() -> void:
    var painter = load("res://scripts/painted_limb_warp.gd").new()
    var source := Image.create(100, 100, false, Image.FORMAT_RGBA8)
    source.fill(Color(0, 0, 0, 0))
    # Draw a deliberately nonuniform red-and-blue painted sleeve.
    for y in range(20, 80):
        for x in range(43, 58):
            source.set_pixel(x, y, Color(0.9, 0.1, 0.1, 1.0) if y < 50 else Color(0.1, 0.3, 0.9, 1.0))
    var destination := Image.create(100, 100, false, Image.FORMAT_RGBA8)
    destination.fill(Color("25364a"))
    painter.draw_segment(destination, source, Vector2(50, 20), Vector2(50, 79), Vector2(20, 50), Vector2(79, 50), 8.0)
    var upper: Color = destination.get_pixel(35, 50)
    var lower: Color = destination.get_pixel(65, 50)
    assert(upper.r > upper.b, "Painted upper sleeve lost its original red pixels")
    assert(lower.b > lower.r, "Painted lower sleeve lost its original blue pixels")
    var outside: Color = destination.get_pixel(50, 10)
    assert(outside.b < 0.5, "Background outside limb was overwritten")
    # Regression: alpha interpolation must keep colored edge pixels
    # without leaking RGB from fully transparent neighboring texels.
    var edge_source := Image.create(12, 12, false, Image.FORMAT_RGBA8)
    edge_source.fill(Color(0, 1, 0, 0))
    for y in range(2, 10):
        for x in range(4, 7):
            edge_source.set_pixel(x, y, Color(1, 0, 0, 1))
    var edge_output := Image.create(24, 24, false, Image.FORMAT_RGBA8)
    edge_output.fill(Color(0, 0, 0, 1))
    painter.draw_segment(edge_output, edge_source, Vector2(5, 2), Vector2(5, 9), Vector2(7.3, 4.2), Vector2(17.1, 16.4), 2.0)
    var red_edge_count: int = 0
    for yy in range(24):
        for xx in range(24):
            var pixel: Color = edge_output.get_pixel(xx, yy)
            assert(pixel.g < 0.01, "Transparent green fringe leaked into warped red artwork")
            if pixel.r > 0.15:
                red_edge_count += 1
    assert(red_edge_count > 10, "Warped semi-transparent edge was lost")
    # Verify that the elbow/knee seam is filled using the painted source
    # without replacing its original color with a synthetic joint circle.
    var seam_source := Image.create(60, 60, false, Image.FORMAT_RGBA8)
    seam_source.fill(Color(0, 0, 0, 0))
    for y in range(14, 46):
        for x in range(27, 34):
            seam_source.set_pixel(x, y, Color(0.9, 0.4, 0.1, 1.0))
    var seam_output := Image.create(60, 60, false, Image.FORMAT_RGBA8)
    seam_output.fill(Color(0.1, 0.1, 0.1, 1.0))
    painter.draw_segment(seam_output, seam_source, Vector2(30, 14), Vector2(30, 30), Vector2(20, 15), Vector2(29, 29), 4.0)
    painter.draw_segment(seam_output, seam_source, Vector2(30, 30), Vector2(30, 45), Vector2(29, 29), Vector2(43, 38), 4.0)
    painter.draw_joint(seam_output, seam_source, Vector2(30, 30), Vector2(29, 29), 3.0)
    var seam_pixel: Color = seam_output.get_pixel(29, 29)
    assert(seam_pixel.r > 0.7 and seam_pixel.g > 0.25, "Joint seam failed to preserve original painted pigment")
    assert(seam_output.get_pixel(5, 5).r < 0.2, "Joint seam overwrote the background")
    var original_pose: Array = []
    var moved_pose: Array = []
    for landmark in range(33):
        original_pose.append({"x": 0.5, "y": 0.5, "visibility": 0.99})
        moved_pose.append({"x": 0.5, "y": 0.5, "visibility": 0.99})
    for idx in [11, 12, 23, 24]:
        original_pose[idx]["y"] = 0.2
        moved_pose[idx]["y"] = 0.2
    for idx in [13, 14, 25, 26]:
        original_pose[idx]["y"] = 0.5
        moved_pose[idx]["y"] = 0.5
    for idx in [15, 16, 27, 28]:
        original_pose[idx]["y"] = 0.8
        moved_pose[idx]["y"] = 0.8
        moved_pose[idx]["x"] = 0.7
    var generic_solver: RefCounted = load("res://scripts/pose_keyframe_solver.gd").new()
    var multi_action: Dictionary = generic_solver.render_artwork_sequence(source, original_pose, [
        {"time": 0.0, "pose": original_pose},
        {"time": 0.5, "pose": moved_pose},
        {"time": 1.0, "pose": original_pose}
    ], 12, 8.0)
    assert(multi_action["ok"], "Generic keyframes must render actual character frames")
    assert(multi_action["count"] == 12)
    assert(multi_action["repair_count"] == 0)
    var connected: Dictionary = generic_solver.render_action_sequence(source, original_pose, [
        {"action": "marche", "frame_count": 8, "keyframes": [
            {"time": 0.0, "pose": original_pose}, {"time": 1.0, "pose": moved_pose}]},
        {"action": "repos", "frame_count": 8, "keyframes": [
            {"time": 0.0, "pose": moved_pose}, {"time": 1.0, "pose": original_pose}]}
    ], 3, 8.0)
    assert(connected["ok"], "Connected actions must render articulated frames")
    assert(connected["count"] == 19)
    assert(connected["boundaries"].size() == 2)
    assert(connected["frames"][0] is Image)
    var saved: Dictionary = generic_solver.save_rendered_frames(
        connected, "user://test_multi_action_frames", 30)
    assert(saved["ok"], "Multi-action PNG frames must be saved")
    assert(saved["count"] == 19)
    assert(not saved["mp4_created"], "PNG frames must never be mislabeled MP4")
    assert(FileAccess.file_exists(saved["files"][0]))
    assert(FileAccess.file_exists(saved["files"][-1]))

    var painted_pose: Dictionary = painter.render_articulated_layers(source, original_pose, moved_pose, 8.0)
    assert(painted_pose["ok"])
    var opaque_artwork := Image.create(100, 100, false, Image.FORMAT_RGBA8)
    opaque_artwork.fill(Color.WHITE)
    assert(not painter.render_articulated_layers(opaque_artwork, original_pose, moved_pose)["ok"], "Opaque background must not be warped as limbs")
    assert(painted_pose["limbs"] == 4)
    assert(painted_pose["image"].get_size() == Vector2i(100, 100))
    assert(painted_pose["image"].get_pixel(0, 0).a < 0.01)
    var shifted: Dictionary = painter.translate_body_landmarks(original_pose, 0.1, 0.05, 0.03)
    assert(shifted["ok"])
    assert(is_equal_approx(float(shifted["landmarks"][11]["x"]), 0.6))
    assert(is_equal_approx(float(shifted["landmarks"][0]["x"]), 0.63))
    assert(is_equal_approx(float(shifted["landmarks"][23]["y"]), 0.25))
    var foot_lock: Dictionary = painter.lock_support_foot(shifted["landmarks"], Vector2(0.5, 0.8), "left")
    assert(foot_lock["ok"])
    assert(is_equal_approx(float(foot_lock["landmarks"][31]["x"]), 0.5))
    assert(is_equal_approx(float(foot_lock["landmarks"][31]["y"]), 0.8))
    assert(not painter.lock_support_foot(original_pose, Vector2(0.5, 0.8), "middle")["ok"])
    var moving_poses: Array = [original_pose, shifted["landmarks"], moved_pose]
    var locked_walk: Dictionary = painter.stabilize_stance_sequence(moving_poses, ["left", "left", "right"])
    assert(locked_walk["ok"])
    assert(locked_walk["count"] == 3)
    assert(is_equal_approx(float(locked_walk["poses"][0][31]["x"]), float(locked_walk["poses"][1][31]["x"])))
    assert(not painter.stabilize_stance_sequence(moving_poses, ["left"])["ok"])
    var inferred: Dictionary = painter.infer_support_sides(moving_poses)
    assert(inferred["ok"])
    assert(inferred["sides"].size() == 3)
    var auto_walk: Dictionary = painter.auto_stabilize_walk(moving_poses)
    assert(auto_walk["ok"])
    assert(auto_walk["count"] == 3)
    assert(auto_walk["support_sides"].size() == 3)
    assert(not painter.auto_stabilize_walk([])["ok"])
    var finished_frames: Dictionary = painter.render_stabilized_character_sequence(source, original_pose, moving_poses, 8.0)
    assert(finished_frames["ok"])
    assert(finished_frames["count"] == 3)
    assert(finished_frames["frames"][1].get_size() == Vector2i(100, 100))
    assert(finished_frames["support_sides"].size() == 3)
    var quality: Dictionary = painter.analyze_frame_sequence(finished_frames["frames"])
    assert(quality.has("frozen_pairs"))
    assert(quality["change_ratios"].size() == 2)
    var silhouette: Dictionary = painter.analyze_silhouette_consistency(finished_frames["frames"])
    assert(silhouette["areas"].size() == 3)
    assert(silhouette["abrupt_scale_pairs"] >= 0)
    var preflight: Dictionary = painter.validate_character_sequence(finished_frames["frames"])
    assert(preflight.has("temporal"))
    assert(not painter.validate_character_sequence([source, source])["ok"])
    var blank := Image.create(100, 100, false, Image.FORMAT_RGBA8)
    blank.fill(Color.TRANSPARENT)
    assert(not painter.analyze_silhouette_consistency([source, blank], 0.1)["ok"])
    assert(not painter.analyze_frame_sequence([source, source])["ok"])
    assert(not painter.analyze_frame_sequence([source])["ok"])
    assert(not painter.render_stabilized_character_sequence(source, original_pose, [])["ok"])
    var composite: Dictionary = painter.render_composite_preview(source, original_pose, moved_pose, 8.0)
    assert(composite["ok"])
    assert(composite["image"].get_size() == Vector2i(100, 100))
    assert(composite["status"] == "translated_head_torso_moving_limbs_preview")
    var translated_preview: Dictionary = painter.render_composite_preview(source, original_pose, shifted["landmarks"], 8.0)
    assert(translated_preview["ok"])
    assert(translated_preview["image"].get_size() == Vector2i(100, 100))
    assert(composite["image"].get_pixel(0, 0).a < 0.01)
    var motion_rig = load("res://scripts/continuous_rig.gd").new()
    var intermediate: Dictionary = motion_rig.transition_between_actions(original_pose, moved_pose, 6)
    assert(intermediate["ok"])
    var motion: Dictionary = painter.render_motion_sequence(source, original_pose, intermediate["frames"], 8.0)
    assert(motion["ok"])
    assert(motion["count"] == 6)
    assert(motion["frames"][0].get_size() == Vector2i(100, 100))
    assert(motion["frames"][0].get_pixel(0, 0).a < 0.01)
    assert(not painter.render_motion_sequence(source, original_pose, [])["ok"])
    # Export a 60-frame composited motion preview for visual CI inspection.
    # The test drawing is synthetic; this does not validate arbitrary photos.
    DirAccess.make_dir_recursive_absolute("user://character_preview")
    var first_preview: Image = null
    var visibly_changed: bool = false
    var transparent_preview_frames: Array = []
    var wrist_min: float = INF
    var wrist_max: float = -INF
    var ankle_min: float = INF
    var ankle_max: float = -INF
    for frame_id in range(60):
        var t: float = float(frame_id) / 59.0
        var moving_t: float = minf(float(frame_id), 40.0) / 59.0
        var travel: Dictionary = painter.translate_body_landmarks(original_pose, 0.12 * moving_t, 0.03 * sin(moving_t * TAU), 0.015 * sin(moving_t * TAU * 2.0))
        assert(travel["ok"])
        # Move arm and leg joints independently: a translated still image is not animation.
        var animated_pose: Array = travel["landmarks"]
        # Three consecutive phases: walk, run, then stop with a settled pose.
        var phase: String = "walk" if frame_id < 20 else ("run" if frame_id < 40 else "stop")
        var phase_t: float = float(frame_id % 20) / 20.0
        var gait: float = sin(phase_t * TAU * (1.0 if phase == "walk" else 2.0)) if phase != "stop" else 0.0
        # Smooth the action amplitude across phase boundaries to avoid a pop.
        var stride: float = 0.65 if phase == "walk" else (1.0 if phase == "run" else 0.0)
        if frame_id >= 20 and frame_id < 25:
            stride = lerpf(0.65, 1.0, float(frame_id - 20) / 5.0)
        # The stop is a genuine held pose, not an oscillation that expands the silhouette.
        animated_pose[15]["x"] = float(animated_pose[15]["x"]) + 0.07 * gait * stride
        animated_pose[16]["x"] = float(animated_pose[16]["x"]) - 0.10 * gait * stride
        animated_pose[27]["x"] = float(animated_pose[27]["x"]) - 0.06 * gait * stride
        animated_pose[28]["x"] = float(animated_pose[28]["x"]) + 0.08 * gait * stride
        wrist_min = minf(wrist_min, float(animated_pose[15]["x"]))
        wrist_max = maxf(wrist_max, float(animated_pose[15]["x"]))
        ankle_min = minf(ankle_min, float(animated_pose[27]["x"]))
        ankle_max = maxf(ankle_max, float(animated_pose[27]["x"]))
        animated_pose[15]["y"] = float(animated_pose[15]["y"]) - 0.03 * absf(gait)
        animated_pose[16]["y"] = float(animated_pose[16]["y"]) - 0.03 * absf(gait)
        var preview: Dictionary = painter.render_composite_preview(source, original_pose, animated_pose, 8.0)
        assert(preview["ok"])
        transparent_preview_frames.append(preview["image"])
        var canvas := Image.create(100, 100, false, Image.FORMAT_RGBA8)
        canvas.fill(Color("25364a"))
        canvas.blend_rect(preview["image"], Rect2i(Vector2i.ZERO, Vector2i(100, 100)), Vector2i.ZERO)
        if frame_id == 0:
            first_preview = canvas.duplicate()
        elif frame_id == 30:
            for check_y in range(100):
                for check_x in range(100):
                    var current_pixel: Color = canvas.get_pixel(check_x, check_y)
                    var initial_pixel: Color = first_preview.get_pixel(check_x, check_y)
                    if absf(current_pixel.r - initial_pixel.r) + absf(current_pixel.g - initial_pixel.g) + absf(current_pixel.b - initial_pixel.b) > 0.1:
                        visibly_changed = true
                        break
                if visibly_changed:
                    break
        if canvas.save_png("user://character_preview/frame_%03d.png" % frame_id) != OK:
            push_error("Could not export character preview")
            quit(1)
            return
    assert(visibly_changed, "Composite preview has no visible movement between frames 0 and 30")
    assert(wrist_max - wrist_min > 0.12, "Arm is not articulated enough")
    assert(ankle_max - ankle_min > 0.10, "Leg is not articulated enough")
    var export_preflight: Dictionary = painter.validate_character_sequence(transparent_preview_frames)
    if not bool(export_preflight.get("ok", false)):
        push_error("Character video quality preflight failed: " + str(export_preflight))
        quit(1)
        return
    print("CHARACTER_VIDEO_PREFLIGHT_OK")
    original_pose[11]["visibility"] = 0.0
    assert(not painter.render_articulated_layers(source, original_pose, moved_pose)["ok"])
    # Produce an actual sequence of painted-limb frames, not just one pose.
    DirAccess.make_dir_recursive_absolute("user://painted_warp")
    for frame in range(60):
        var picture := Image.create(100, 100, false, Image.FORMAT_RGBA8)
        picture.fill(Color("25364a"))
        var theta: float = sin(float(frame) / 60.0 * TAU) * 0.7
        var end_point := Vector2(50.0 + 59.0 * sin(theta), 20.0 + 59.0 * cos(theta))
        painter.draw_segment(picture, source, Vector2(50, 20), Vector2(50, 79), Vector2(50, 20), end_point, 8.0)
        if picture.save_png("user://painted_warp/frame_%03d.png" % frame) != OK:
            push_error("Could not export painted frame")
            quit(1)
            return
    print("PAINTED_LIMB_WARP_OK")
    quit(0)
