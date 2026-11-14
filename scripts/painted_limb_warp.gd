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
    for py in range(0, artwork.get_height(), maxi(1, artwork.get_height() / 16)):
        for px in range(0, artwork.get_width(), maxi(1, artwork.get_width() / 16)):
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
