extends RefCounted
class_name ReferenceSceneAnalyzer

# Deterministic image inventory. No unsupported semantic/identity claims.
# Stores source dimensions, palette and reference file unchanged for later ML.
static func analyze(path: String, root: String) -> Dictionary:
    if not root.begins_with("user://"):
        return {"ok": false, "error": "invalid_output"}
    var image := Image.new()
    if image.load(path) != OK or image.is_empty():
        return {"ok": false, "error": "invalid_reference"}
    var original_size := image.get_size()
    if original_size.x < 16 or original_size.y < 16:
        return {"ok": false, "error": "image_too_small"}
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) != OK:
        return {"ok": false, "error": "cannot_create_directory"}
    var original := root + "/reference_original.png"
    if image.save_png(original) != OK:
        return {"ok": false, "error": "cannot_save_reference"}
    var sample := image.duplicate()
    sample.resize(24, 24, Image.INTERPOLATE_BILINEAR)
    var palette: Array = []
    var bins: Dictionary = {}
    for y in range(sample.get_height()):
        for x in range(sample.get_width()):
            var color := sample.get_pixel(x, y)
            var key := "%d_%d_%d" % [int(color.r * 5.0), int(color.g * 5.0), int(color.b * 5.0)]
            bins[key] = int(bins.get(key, 0)) + 1
    var sorted_keys := bins.keys()
    sorted_keys.sort_custom(func(a, b): return int(bins[a]) > int(bins[b]))
    for i in range(mini(6, sorted_keys.size())):
        var pieces := str(sorted_keys[i]).split("_")
        palette.append(Color(float(int(pieces[0])) / 5.0, float(int(pieces[1])) / 5.0, float(int(pieces[2])) / 5.0).to_html(false))
    var profile := {
        "reference_image": original,
        "width": original_size.x,
        "height": original_size.y,
        "aspect_ratio": float(original_size.x) / float(original_size.y),
        "palette": palette,
        "subject_mask": "",
        "subject_description": "",
        "background_description": "",
        "objects": [],
        "scene_layout": {},
        "analysis_level": "image_metadata_only",
        "needs_segmentation_model": true,
        "needs_visual_understanding_model": true
    }
    var output := FileAccess.open(root + "/scene_profile.json", FileAccess.WRITE)
    if output == null:
        return {"ok": false, "error": "cannot_save_profile"}
    output.store_string(JSON.stringify(profile, "  "))
    output.close()
    return {"ok": true, "profile": profile, "profile_path": root + "/scene_profile.json"}
