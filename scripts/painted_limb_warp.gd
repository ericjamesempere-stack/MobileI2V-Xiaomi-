extends RefCounted
# Reprojects the actual pixels of a painted limb along a two-bone IK chain.
# Input artwork stays intact; no solid-color replacement or rectangle copying.
# This is a prototype for pre-separated transparent limb layers.

func draw_segment(dst: Image, artwork: Image, source_a: Vector2, source_b: Vector2, target_a: Vector2, target_b: Vector2, half_width: float) -> void:
    var source_axis: Vector2 = source_b - source_a
    var target_axis: Vector2 = target_b - target_a
    var source_length: float = source_axis.length()
    var target_length: float = target_axis.length()
    if source_length < 1.0 or target_length < 1.0 or half_width <= 0.0:
        return
    var source_forward: Vector2 = source_axis / source_length
    var source_side := Vector2(-source_forward.y, source_forward.x)
    var target_forward: Vector2 = target_axis / target_length
    var target_side := Vector2(-target_forward.y, target_forward.x)
    var left: int = maxi(0, floori(minf(target_a.x, target_b.x) - half_width - 2.0))
    var right: int = mini(dst.get_width() - 1, ceili(maxf(target_a.x, target_b.x) + half_width + 2.0))
    var top: int = maxi(0, floori(minf(target_a.y, target_b.y) - half_width - 2.0))
    var bottom: int = mini(dst.get_height() - 1, ceili(maxf(target_a.y, target_b.y) + half_width + 2.0))
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            var relative := Vector2(float(x), float(y)) - target_a
            var along: float = relative.dot(target_forward)
            var side: float = relative.dot(target_side)
            # Do not extrapolate the painted texture beyond its bone endpoints:
            # endpoint overlap is handled explicitly by draw_joint().
            if along < 0.0 or along > target_length or absf(side) > half_width:
                continue
            var source_point := source_a + source_forward * (along / target_length * source_length) + source_side * side
            # Bilinear alpha-aware sampling avoids hard nearest-neighbour
            # pixel staircases along rotated clothing and silhouette edges.
            var sx: int = floori(source_point.x)
            var sy: int = floori(source_point.y)
            var tx: float = source_point.x - float(sx)
            var ty: float = source_point.y - float(sy)
            var weighted_alpha: float = 0.0
            var premultiplied := Vector3.ZERO
            for oy in range(2):
                for ox in range(2):
                    var px: int = sx + ox
                    var py: int = sy + oy
                    if px < 0 or py < 0 or px >= artwork.get_width() or py >= artwork.get_height():
                        continue
                    var weight: float = (tx if ox == 1 else 1.0 - tx) * (ty if oy == 1 else 1.0 - ty)
                    var sample: Color = artwork.get_pixel(px, py)
                    var contribution: float = weight * sample.a
                    weighted_alpha += contribution
                    premultiplied += Vector3(sample.r, sample.g, sample.b) * contribution
            if weighted_alpha <= 0.001:
                continue
            var pigment_rgb: Vector3 = premultiplied / weighted_alpha
            var opacity: float = weighted_alpha * clampf(half_width + 0.5 - absf(side), 0.0, 1.0)
            var original: Color = dst.get_pixel(x, y)
            dst.set_pixel(x, y, original.lerp(Color(pigment_rgb.x, pigment_rgb.y, pigment_rgb.z, 1.0), opacity))

# Covers the tiny gap between two independently warped segments with
# artwork sampled around their original joint. No synthetic flat color.
func draw_joint(dst: Image, artwork: Image, source_joint: Vector2, target_joint: Vector2, radius: float) -> void:
    if radius <= 0.0:
        return
    var left: int = maxi(0, floori(target_joint.x - radius - 1.0))
    var right: int = mini(dst.get_width() - 1, ceili(target_joint.x + radius + 1.0))
    var top: int = maxi(0, floori(target_joint.y - radius - 1.0))
    var bottom: int = mini(dst.get_height() - 1, ceili(target_joint.y + radius + 1.0))
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            var offset := Vector2(float(x), float(y)) - target_joint
            var distance: float = offset.length()
            if distance > radius + 0.5:
                continue
            var sx: int = roundi(source_joint.x + offset.x)
            var sy: int = roundi(source_joint.y + offset.y)
            if sx < 0 or sy < 0 or sx >= artwork.get_width() or sy >= artwork.get_height():
                continue
            var pigment: Color = artwork.get_pixel(sx, sy)
            if pigment.a <= 0.001:
                continue
            var alpha: float = pigment.a * clampf(radius + 0.5 - distance, 0.0, 1.0)
            dst.set_pixel(x, y, dst.get_pixel(x, y).lerp(Color(pigment.r, pigment.g, pigment.b, 1.0), alpha))

# Transfer articulated movement onto a pre-separated transparent character
# drawing. Requires verified MediaPipe landmarks for the SOURCE drawing and
# target pose. This is not automatic segmentation of arbitrary photographs.
func render_articulated_layers(artwork: Image, source_landmarks: Array, target_landmarks: Array, limb_half_width: float = 9.0) -> Dictionary:
    var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
    var source_check: Dictionary = rig.validate_landmarks(source_landmarks)
    var target_check: Dictionary = rig.validate_landmarks(target_landmarks)
    if not bool(source_check.get("ok", false)) or not bool(target_check.get("ok", false)):
        return {"ok": false, "error": "Source and target body landmarks required"}
    if artwork.is_empty() or artwork.get_width() < 32 or artwork.get_height() < 32:
        return {"ok": false, "error": "Character artwork missing"}
    # Reject opaque photographs: warping their background as clothing creates ghosts.
    var transparent_samples: int = 0
    var sample_count: int = 0
    for py in range(0, artwork.get_height(), maxi(1, floori(float(artwork.get_height()) / 16.0))):
        for px in range(0, artwork.get_width(), maxi(1, floori(float(artwork.get_width()) / 16.0))):
            sample_count += 1
            if artwork.get_pixel(px, py).a < 0.1:
                transparent_samples += 1
    if sample_count == 0 or float(transparent_samples) / float(sample_count) < 0.05:
        return {"ok": false, "error": "Transparent character cutout required; opaque photograph cannot be safely warped"}
    var image := Image.create(artwork.get_width(), artwork.get_height(), false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var w: float = float(artwork.get_width())
    var h: float = float(artwork.get_height())
    var limbs: Array = [[11, 13, 15], [12, 14, 16], [23, 25, 27], [24, 26, 28]]
    for limb in limbs:
        var source_a := Vector2(float(source_landmarks[limb[0]]["x"]) * w, float(source_landmarks[limb[0]]["y"]) * h)
        var source_b := Vector2(float(source_landmarks[limb[1]]["x"]) * w, float(source_landmarks[limb[1]]["y"]) * h)
        var source_c := Vector2(float(source_landmarks[limb[2]]["x"]) * w, float(source_landmarks[limb[2]]["y"]) * h)
        var target_a := Vector2(float(target_landmarks[limb[0]]["x"]) * w, float(target_landmarks[limb[0]]["y"]) * h)
        var target_b := Vector2(float(target_landmarks[limb[1]]["x"]) * w, float(target_landmarks[limb[1]]["y"]) * h)
        var target_c := Vector2(float(target_landmarks[limb[2]]["x"]) * w, float(target_landmarks[limb[2]]["y"]) * h)
        draw_segment(image, artwork, source_a, source_b, target_a, target_b, limb_half_width)
        draw_segment(image, artwork, source_b, source_c, target_b, target_c, limb_half_width)
        draw_joint(image, artwork, source_b, target_b, limb_half_width * 0.7)
    return {"ok": true, "image": image, "limbs": limbs.size(), "status": "painted_limbs_only"}

# Render a chronological sequence using the SAME source artwork for every pose.
# No crossfade or replacement drawing: each frame reprojects painted limb pixels.
func render_motion_sequence(artwork: Image, source_landmarks: Array, target_poses: Array, limb_half_width: float = 9.0) -> Dictionary:
    if target_poses.is_empty():
        return {"ok": false, "error": "No target poses", "frames": []}
    if target_poses.size() > 300:
        return {"ok": false, "error": "Too many poses in one batch", "frames": []}
    var frames: Array[Image] = []
    for pose in target_poses:
        if not pose is Array:
            return {"ok": false, "error": "Invalid pose format", "frames": []}
        var result: Dictionary = render_articulated_layers(artwork, source_landmarks, pose, limb_half_width)
        if not bool(result.get("ok", false)):
            return {"ok": false, "error": str(result.get("error", "Invalid pose")), "frames": []}
        frames.append(result["image"])
    return {"ok": true, "frames": frames, "count": frames.size(),
        "status": "painted_limb_sequence", "scope": "four_limbs_only"}

# Preview-only compositor: keep original head/torso pixels while painting
# articulated limbs. Explicitly NOT a full-body rig: torso and head are static.
func render_composite_preview(artwork: Image, source_landmarks: Array, target_landmarks: Array, limb_half_width: float = 9.0) -> Dictionary:
    var moved: Dictionary = render_articulated_layers(artwork, source_landmarks, target_landmarks, limb_half_width)
    if not bool(moved.get("ok", false)):
        return moved
    var w: int = artwork.get_width()
    var h: int = artwork.get_height()
    var result := Image.create(w, h, false, Image.FORMAT_RGBA8)
    result.fill(Color.TRANSPARENT)
    var left_shoulder: Dictionary = source_landmarks[11]
    var right_shoulder: Dictionary = source_landmarks[12]
    var left_hip: Dictionary = source_landmarks[23]
    var right_hip: Dictionary = source_landmarks[24]
    var shoulder_center := Vector2((float(left_shoulder["x"]) + float(right_shoulder["x"])) * 0.5 * w,
        (float(left_shoulder["y"]) + float(right_shoulder["y"])) * 0.5 * h)
    var hip_center := Vector2((float(left_hip["x"]) + float(right_hip["x"])) * 0.5 * w,
        (float(left_hip["y"]) + float(right_hip["y"])) * 0.5 * h)
    var torso_half_width: float = maxf(2.0, absf(float(left_shoulder["x"]) - float(right_shoulder["x"])) * w * 0.7)
    var head_radius: float = maxf(3.0, torso_half_width * 0.75)
    var target_shoulder := Vector2((float(target_landmarks[11]["x"]) + float(target_landmarks[12]["x"])) * 0.5 * w,
        (float(target_landmarks[11]["y"]) + float(target_landmarks[12]["y"])) * 0.5 * h)
    var target_hip := Vector2((float(target_landmarks[23]["x"]) + float(target_landmarks[24]["x"])) * 0.5 * w,
        (float(target_landmarks[23]["y"]) + float(target_landmarks[24]["y"])) * 0.5 * h)
    var body_shift: Vector2 = ((target_shoulder - shoulder_center) + (target_hip - hip_center)) * 0.5
    var source_head := shoulder_center - Vector2(0.0, head_radius * 1.2)
    var head_shift := target_shoulder - shoulder_center
    # Independent nose offset allows subtle head sway while the torso moves.
    head_shift += Vector2((float(target_landmarks[0]["x"]) - float(source_landmarks[0]["x"])) * w, (float(target_landmarks[0]["y"]) - float(source_landmarks[0]["y"])) * h) - (target_shoulder - shoulder_center)
    for y in range(h):
        for x in range(w):
            var p := Vector2(float(x), float(y))
            var body_pixel: bool = absf(p.x - lerpf(shoulder_center.x, hip_center.x, clampf((p.y - shoulder_center.y) / maxf(1.0, hip_center.y - shoulder_center.y), 0.0, 1.0))) <= torso_half_width and p.y >= shoulder_center.y and p.y <= hip_center.y
            var head_pixel: bool = p.distance_to(source_head) <= head_radius
            if body_pixel or head_pixel:
                var offset: Vector2 = head_shift if head_pixel else body_shift
                var target_x: int = roundi(p.x + offset.x)
                var target_y: int = roundi(p.y + offset.y)
                if target_x >= 0 and target_y >= 0 and target_x < w and target_y < h:
                    result.set_pixel(target_x, target_y, artwork.get_pixel(x, y))
    var limbs: Image = moved["image"]
    result.blend_rect(limbs, Rect2i(Vector2i.ZERO, limbs.get_size()), Vector2i.ZERO)
    return {"ok": true, "image": result, "status": "translated_head_torso_moving_limbs_preview",
        "limitations": ["head and torso translate but do not rotate", "source character must be pre-separated", "no occlusion ordering"]}

# Simple hierarchical body sway: hips anchor the torso, shoulders and head
# follow a common translation. This preview is intentionally 2D only.
func translate_body_landmarks(source_landmarks: Array, dx: float, dy: float, head_sway: float = 0.0) -> Dictionary:
    var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
    if not bool(rig.validate_landmarks(source_landmarks).get("ok", false)):
        return {"ok": false, "error": "Invalid source landmarks"}
    var shifted: Array = []
    for i in range(source_landmarks.size()):
        var point: Dictionary = source_landmarks[i].duplicate()
        var horizontal: float = dx
        if i <= 10:
            horizontal += head_sway
        point["x"] = clampf(float(point["x"]) + horizontal, 0.0, 1.0)
        point["y"] = clampf(float(point["y"]) + dy, 0.0, 1.0)
        shifted.append(point)
    return {"ok": true, "landmarks": shifted, "type": "body_translation_with_head_sway"}

# Stabilize a planted foot in image coordinates by translating the entire pose.
# Caller chooses the support side; the other foot remains free to swing.
# Useful for reducing sliding during walk/run contact phases.
func lock_support_foot(pose: Array, anchor: Vector2, side: String = "left") -> Dictionary:
    var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
    if not bool(rig.validate_landmarks(pose).get("ok", false)):
        return {"ok": false, "error": "Invalid pose"}
    if side != "left" and side != "right":
        return {"ok": false, "error": "Unknown support foot"}
    var foot_index: int = 31 if side == "left" else 32
    var foot: Dictionary = pose[foot_index]
    var dx: float = anchor.x - float(foot["x"])
    var dy: float = anchor.y - float(foot["y"])
    var corrected: Array = []
    for point in pose:
        var p: Dictionary = point.duplicate()
        p["x"] = float(p["x"]) + dx
        p["y"] = float(p["y"]) + dy
        corrected.append(p)
    return {"ok": true, "landmarks": corrected, "support_foot": side,
        "translation": Vector2(dx, dy), "type": "root_translation_foot_lock"}

# Apply one support-foot anchor across a stance phase, retaining the original
# pose ordering. A new anchor is captured when support switches.
func stabilize_stance_sequence(poses: Array, support_sides: Array) -> Dictionary:
    if poses.is_empty() or poses.size() != support_sides.size():
        return {"ok": false, "error": "Pose/support sequence mismatch", "poses": []}
    var corrected: Array = []
    var anchor := Vector2.ZERO
    var previous_side: String = ""
    for i in range(poses.size()):
        var side: String = str(support_sides[i])
        if side != "left" and side != "right":
            return {"ok": false, "error": "Invalid support side at frame %d" % i, "poses": []}
        var pose: Array = poses[i]
        var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
        if not bool(rig.validate_landmarks(pose).get("ok", false)):
            return {"ok": false, "error": "Invalid landmarks at frame %d" % i, "poses": []}
        if side != previous_side:
            var idx: int = 31 if side == "left" else 32
            anchor = Vector2(float(pose[idx]["x"]), float(pose[idx]["y"]))
            previous_side = side
        var locked: Dictionary = lock_support_foot(pose, anchor, side)
        if not bool(locked.get("ok", false)):
            return {"ok": false, "error": "Foot lock failed at frame %d" % i, "poses": []}
        corrected.append(locked["landmarks"])
    return {"ok": true, "poses": corrected, "count": corrected.size(), "type": "stance_locked"}

# Choose support foot automatically from per-frame landmark displacement.
# Lower motion is treated as stance; ties retain previous support.
# This is a heuristic, not a physics/contact detector.
func infer_support_sides(poses: Array, initial_side: String = "left") -> Dictionary:
    if poses.is_empty() or (initial_side != "left" and initial_side != "right"):
        return {"ok": false, "error": "Invalid input", "sides": []}
    var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
    var sides: Array[String] = []
    var previous: Array = []
    var side: String = initial_side
    for i in range(poses.size()):
        var pose: Array = poses[i]
        if not bool(rig.validate_landmarks(pose).get("ok", false)):
            return {"ok": false, "error": "Invalid landmarks at frame %d" % i, "sides": []}
        if i > 0:
            var left_now := Vector2(float(pose[31]["x"]), float(pose[31]["y"]))
            var left_before := Vector2(float(previous[31]["x"]), float(previous[31]["y"]))
            var right_now := Vector2(float(pose[32]["x"]), float(pose[32]["y"]))
            var right_before := Vector2(float(previous[32]["x"]), float(previous[32]["y"]))
            var left_motion: float = left_now.distance_to(left_before)
            var right_motion: float = right_now.distance_to(right_before)
            if absf(left_motion - right_motion) > 0.002:
                side = "left" if left_motion < right_motion else "right"
        sides.append(side)
        previous = pose
    return {"ok": true, "sides": sides, "method": "foot_displacement_heuristic"}

func auto_stabilize_walk(poses: Array, initial_side: String = "left") -> Dictionary:
    var inferred: Dictionary = infer_support_sides(poses, initial_side)
    if not bool(inferred.get("ok", false)):
        return inferred
    var stabilized: Dictionary = stabilize_stance_sequence(poses, inferred["sides"])
    if bool(stabilized.get("ok", false)):
        stabilized["support_sides"] = inferred["sides"]
        stabilized["contact_method"] = inferred["method"]
    return stabilized

# End-to-end CPU preview: infer contact, stabilize each pose and render a
# composited character frame. Caller can feed the returned images to the MP4
# encoder. Source artwork must already be separated and landmarked.
func render_stabilized_character_sequence(artwork: Image, source_landmarks: Array, target_poses: Array, limb_half_width: float = 9.0) -> Dictionary:
    var stance: Dictionary = auto_stabilize_walk(target_poses)
    if not bool(stance.get("ok", false)):
        return {"ok": false, "error": str(stance.get("error", "Stance detection failed")), "frames": []}
    var frames: Array[Image] = []
    for pose in stance["poses"]:
        var composite: Dictionary = render_composite_preview(artwork, source_landmarks, pose, limb_half_width)
        if not bool(composite.get("ok", false)):
            return {"ok": false, "error": str(composite.get("error", "Character render failed")), "frames": []}
        frames.append(composite["image"])
    return {"ok": true, "frames": frames, "count": frames.size(),
        "support_sides": stance["support_sides"],
        "status": "stabilized_composite_frames",
        "limitations": ["requires transparent pre-separated artwork and landmarks",
            "head and torso only translate", "no automatic pose synthesis", "no video encoding"]}

# Quality gate for image sequences: detect identical frames and abrupt changes.
# Uses sparse RGBA pixel sampling for a low-memory, CPU-only preview check.
func analyze_frame_sequence(frames: Array, max_jump_ratio: float = 0.65) -> Dictionary:
    if frames.size() < 2:
        return {"ok": false, "error": "At least two frames required"}
    var previous: Image = frames[0]
    if previous == null or previous.is_empty():
        return {"ok": false, "error": "Empty first frame"}
    var width: int = previous.get_width()
    var height: int = previous.get_height()
    var jump_ratios: Array[float] = []
    var frozen_pairs: int = 0
    var abrupt_pairs: int = 0
    var samples: int = 0
    for i in range(1, frames.size()):
        var current: Image = frames[i]
        if current == null or current.is_empty() or current.get_size() != previous.get_size():
            return {"ok": false, "error": "Missing or mismatched frame at %d" % i}
        var changed: int = 0
        samples = 0
        for y in range(0, height, maxi(1, floori(float(height) / 32.0))):
            for x in range(0, width, maxi(1, floori(float(width) / 32.0))):
                samples += 1
                var a: Color = previous.get_pixel(x, y)
                var b: Color = current.get_pixel(x, y)
                if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a) > 0.25:
                    changed += 1
        var ratio: float = float(changed) / float(maxi(1, samples))
        jump_ratios.append(ratio)
        if changed == 0:
            frozen_pairs += 1
        if ratio > max_jump_ratio:
            abrupt_pairs += 1
        previous = current
    return {"ok": frozen_pairs < frames.size() - 1 and abrupt_pairs == 0,
        "frozen_pairs": frozen_pairs, "abrupt_pairs": abrupt_pairs,
        "change_ratios": jump_ratios,
        "status": "sequence_quality_checked",
        "limitations": ["sparse sampling can miss subtle motion", "no identity or anatomy scoring"]}

# Measure whether the character's opaque silhouette changes size dramatically
# between frames. This catches some cutout flicker and sudden body scale jumps.
func analyze_silhouette_consistency(frames: Array, max_area_change: float = 0.30) -> Dictionary:
    if frames.size() < 2:
        return {"ok": false, "error": "At least two frames required"}
    var areas: Array[int] = []
    var abrupt_scale_pairs: int = 0
    var previous_area: int = -1
    for i in range(frames.size()):
        if not frames[i] is Image:
            return {"ok": false, "error": "Invalid frame at %d" % i}
        var frame: Image = frames[i]
        if frame.is_empty():
            return {"ok": false, "error": "Empty frame at %d" % i}
        var area: int = 0
        for y in range(0, frame.get_height(), 2):
            for x in range(0, frame.get_width(), 2):
                if frame.get_pixel(x, y).a > 0.5:
                    area += 1
        areas.append(area)
        if previous_area >= 0:
            var delta: float = absf(float(area - previous_area)) / float(maxi(1, previous_area))
            if delta > max_area_change:
                abrupt_scale_pairs += 1
        previous_area = area
    return {"ok": abrupt_scale_pairs == 0, "areas": areas,
        "abrupt_scale_pairs": abrupt_scale_pairs,
        "status": "silhouette_area_checked",
        "limitations": ["alpha-only silhouette", "does not measure identity or anatomy"]}

# Run both checks on the original transparent RGBA frames before compositing
# onto a solid video background. Fail closed when either check reports an issue.
func validate_character_sequence(frames: Array, max_jump_ratio: float = 0.65, max_area_change: float = 0.30) -> Dictionary:
    var temporal: Dictionary = analyze_frame_sequence(frames, max_jump_ratio)
    if not bool(temporal.get("ok", false)):
        return {"ok": false, "error": "Temporal continuity failed",
            "temporal": temporal}
    var silhouette: Dictionary = analyze_silhouette_consistency(frames, max_area_change)
    if not bool(silhouette.get("ok", false)):
        return {"ok": false, "error": "Silhouette continuity failed",
            "temporal": temporal, "silhouette": silhouette}
    return {"ok": true, "status": "character_sequence_preflight_passed",
        "frame_count": frames.size(), "temporal": temporal,
        "silhouette": silhouette,
        "limitations": ["heuristic preflight only", "no anatomical or identity validation"]}
