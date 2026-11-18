extends SceneTree
# LIVE remote inference probe: no simulation, no API keys, no APK build.
# A failed provider is recorded, never represented as a generated image.
const OUT := "user://live-provider-proof"
const PROMPT := "Two cheerful cartoon bananas standing side by side in a simple studio, distinct faces, yellow banana bodies, no humans, clean outlines."
var results: Array = []
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var worker: Node = load("res://scripts/hf_studio_generator.gd").new()
    root.add_child(worker)
    var source := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    source.fill(Color(0.94, 0.91, 0.79))
    source.fill_rect(Rect2i(95, 45, 65, 170), Color(1.0, 0.83, 0.08))
    source.save_png(OUT.path_join("reference.png"))
    var generated: Array[Image] = []
    var first: Dictionary = await worker.create_reference(PROMPT, "cartoon")
    _record("z_image_text", first, generated)
    var steps: Array[String] = [
        "The two banana characters look surprised with wide eyes; preserve their banana shapes and colors.",
        "The two banana characters raise their arms in surprise; preserve their identity and scene.",
        "Small red devil horns grow on top of both banana characters; preserve the rest of their anatomy."
    ]
    var previous: Image = first["image"] if first.get("ok", false) and first.get("image") is Image else source
    for i in range(steps.size()):
        var response: Dictionary = await worker.redraw(previous, steps[i], "cartoon", previous)
        _record("edit_%02d" % i, response, generated)
        if response.get("ok", false) and response.get("image") is Image:
            previous = response["image"]
        else:
            break
    if not generated.is_empty():
        var cell := Vector2i(320, 320)
        var sheet := Image.create(cell.x * 2, cell.y * int(ceili(float(generated.size()) / 2.0)), false, Image.FORMAT_RGBA8)
        sheet.fill(Color.WHITE)
        for i in range(generated.size()):
            var frame: Image = generated[i].duplicate()
            frame.convert(Image.FORMAT_RGBA8)
            frame.resize(cell.x, cell.y)
            sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), Vector2i(i % 2 * cell.x, i / 2 * cell.y))
        sheet.save_png(OUT.path_join("contact_sheet.png"))
    var report := {"real_inference": true, "simulated": false, "results": results, "generated_images": generated.size(), "contact_sheet": generated.size() > 0, "analysis": {"visual_quality": "requires manual inspection", "identity_verified": false, "pose_verified": false, "fallback_tested": results.any(func(r): return str(r.get("engine", "")) == "anypose")}}
    var file := FileAccess.open(OUT.path_join("report.json"), FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(report, "\t"))
        file.close()
    print("KARMA_LIVE_PROVIDER_REPORT=" + JSON.stringify(report))
    worker.queue_free()
    quit(0)
func _record(label: String, response: Dictionary, generated: Array[Image]) -> void:
    var row := {"step": label, "ok": bool(response.get("ok", false)), "engine": str(response.get("engine", response.get("model", ""))), "error": str(response.get("error", "")), "error_kind": str(response.get("error_kind", "")), "http_status": int(response.get("http_status", 0))}
    if response.get("ok", false) and response.get("image") is Image:
        var img: Image = response["image"]
        if not img.is_empty():
            var path: String = OUT.path_join("%02d_%s.png" % [generated.size(), label])
            if img.save_png(path) == OK:
                generated.append(img)
                row["file"] = path.get_file()
                row["dimensions"] = [img.get_width(), img.get_height()]
    results.append(row)
