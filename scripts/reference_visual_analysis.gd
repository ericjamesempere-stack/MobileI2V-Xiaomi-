extends RefCounted
# Deterministic visual measurements from the actual selected image.
# Not a semantic vision model: never invents subject identity or clothing.
func analyze(source: Image) -> Dictionary:
    if source == null or source.is_empty():
        return {"ok": false, "error": "empty_reference"}
    var img: Image = source.duplicate()
    img.convert(Image.FORMAT_RGBA8)
    var w: int = img.get_width()
    var h: int = img.get_height()
    var stride: int = maxi(1, maxi(w, h) / 256)
    var visible: int = 0
    var total: int = 0
    var min_x: int = w
    var min_y: int = h
    var max_x: int = -1
    var max_y: int = -1
    for y in range(0, h, stride):
        for x in range(0, w, stride):
            total += 1
            if img.get_pixel(x, y).a < 0.5:
                continue
            visible += 1
            min_x = mini(min_x, x)
            min_y = mini(min_y, y)
            max_x = maxi(max_x, x)
            max_y = maxi(max_y, y)
    if visible < 16:
        return {"ok": false, "error": "reference_has_no_visible_subject"}
    var palette: Dictionary = load("res://scripts/reference_appearance_palette.gd").new().extract(source)
    if not palette.get("ok", false):
        return {"ok": false, "error": "reference_palette_failed"}
    var hex_colors: Array[String] = []
    for color in palette.get("palette", []):
        hex_colors.append("#" + (color as Color).to_html(false))
    # Alpha bounding box only identifies a subject on a transparent image.
    # For opaque photos the whole image is visible: never mislabel it as subject segmentation.
    var has_alpha_subject: bool = visible < total
    var bbox: Rect2 = Rect2(float(min_x) / w, float(min_y) / h, float(max_x - min_x + stride) / w, float(max_y - min_y + stride) / h)
    return {
        "ok": true,
        "width": w,
        "height": h,
        "aspect_ratio": float(w) / float(h),
        "visible_fraction": float(visible) / float(maxi(1, total)),
        "bounds_normalized": bbox,
        "bounds_are_subject": has_alpha_subject,
        "palette_hex": hex_colors,
        "semantic_analysis": false,
        "reference_required": true
    }

func drawing_guidance(profile: Dictionary) -> String:
    if not profile.get("ok", false):
        return ""
    var bounds: Rect2 = profile["bounds_normalized"]
    var bounds_kind: String = "alpha-visible subject bounds" if profile.get("bounds_are_subject", false) else "full opaque photo bounds (NOT subject detection)"
    return "IMAGE-LOCKED REFERENCE: the actual user-selected image is authoritative, not a generic text character. Reference dimensions %d x %d, aspect %.3f, visible coverage %.2f, %s normalized x=%.2f y=%.2f width=%.2f height=%.2f, dominant colors %s. Preserve the reference subject's distinctive silhouette, face if present, hair if present, outfit if present, materials, visual style and palette. Do not invent a human body, new clothing or unrelated subject. Create distinct action keyframes while keeping the same subject recognizable. These are pixel measurements, not semantic AI recognition." % [
        int(profile["width"]), int(profile["height"]), float(profile["aspect_ratio"]), float(profile["visible_fraction"]),
        bounds_kind, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y, ", ".join(profile["palette_hex"])
    ]
