# Real opt-in evaluation through the existing app worker.
# complete means pixels returned, NEVER fidelity/approval/animation success.
extends SceneTree
var DEST: String
func _initialize() -> void:
    call_deferred("run")
func write_json(path: String, data: Dictionary) -> void:
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string(JSON.stringify(data, "  "))
    f.close()
func run() -> void:
    DEST = OS.get_environment("KARMA_V55_EVIDENCE_DIR")
    if OS.get_environment("KARMA_ALLOW_LIVE_INFERENCE") != "1" or DEST.is_empty():
        printerr("Opt-in and KARMA_V55_EVIDENCE_DIR required; no inference attempted")
        quit(2)
        return
    for key in ["KARMA_V55_HUMAN_REFERENCE", "KARMA_V55_BANANA_REFERENCE", "KARMA_V55_COMPLEX_REFERENCE"]:
        if not FileAccess.file_exists(OS.get_environment(key)):
            printerr("Explicit readable test references required; no inference attempted")
            quit(2)
            return
    DirAccess.make_dir_recursive_absolute(DEST)
    var cases: Array = [
        {"id":"human", "reference":OS.get_environment("KARMA_V55_HUMAN_REFERENCE"), "style":"bd_detail", "phases":["The same astronaut in the same orange flight suit faces the camera, with the original NASA background and flag unchanged; neutral posture, hands below the portrait crop.", "The SAME astronaut smiles and raises her own right hand beside her right shoulder in a small wave; preserve her precise face, orange suit, patches, hairstyle, portrait crop and fixed camera. No legs or full body invented outside the reference framing."]},
        {"id":"banana", "reference":OS.get_environment("KARMA_V55_BANANA_REFERENCE"), "style":"bd_detail", "phases":["The exact same single peeled banana with the face drawn on its peel leans slightly LEFT, supported on the same three peel strips on the same wooden kitchen table. Preserve the existing banana anatomy, no new arms, legs, clothes or human torso.", "The exact SAME banana bends its fruit body gently to the RIGHT while its three peel strips retain the same support contacts. Preserve the face, peel shape, kitchen cupboards, pots and table markings. Different physical bend, NOT camera movement. No human body or extra limbs."]},
        {"id":"complex", "reference":OS.get_environment("KARMA_V55_COMPLEX_REFERENCE"), "style":"original", "phases":["Reproduce this EXACT street photograph, preserving every visible pedestrian, the same bus, shop signs, road and building geometry. The people retain their exact faces, clothing and positions. The bus stays stationary. Render a photographic image, fixed camera.", "The SAME pedestrians each take one small walking step forward along the SAME sidewalk, preserving the exact number of people, their clothing, faces and relative order. The SAME bus stays stationary, with the SAME windows, signs, wheels and background buildings. Fixed camera, same focal length and framing. Do not add or remove people or objects; no duplicate limbs."]}
    ]
    var summary: Dictionary = {"real_inference":true, "simulated":false, "semantic_analysis_executed":false, "human_approved":false, "device_test":false, "cases":[]}
    var known_engines: Dictionary = {}
    for test in cases:
        var folder: String = DEST.path_join(test["id"])
        DirAccess.make_dir_recursive_absolute(folder)
        var worker: Node = load("res://scripts/hf_studio_generator.gd").new()
        root.add_child(worker)
        worker.job_folder = folder.path_join("jobs")
        worker.hf_token = OS.get_environment("KARMA_HF_TOKEN")
        worker.engine_status = known_engines.duplicate(true)
        var reference := Image.new()
        var reference_path: String = folder.path_join("reference.png")
        var entry: Dictionary = {"id":test["id"], "real_inference":true, "human_approved":false, "instructions_origin":"explicit test brief, not model-derived scene", "complete":false}
        if FileAccess.file_exists(reference_path):
            reference.load(reference_path)
        elif test.has("reference"):
            reference.load(test["reference"])
            reference.save_png(reference_path)
        else:
            var created: Dictionary = await worker.create_reference(test["description"], test["style"])
            if not created.get("ok", false):
                entry["error"] = created.get("error", "reference_failed")
                write_json(folder.path_join("result.json"), entry)
                summary["cases"].append(entry)
                worker.queue_free()
                await process_frame
                continue
            reference = created["image"]
            reference.save_png(reference_path)
            entry["reference_model"] = created.get("model", "")
        entry["reference_sha256"] = FileAccess.get_sha256(reference_path)
        entry["input_sha256"] = (str(entry["reference_sha256"]) + JSON.stringify(test["phases"]) + str(test["style"])).sha256_text()
        var briefs: Array = []
        for phase in test["phases"]:
            briefs.append({"pose":phase, "description":phase, "instruction":phase})
        var sheet_path: String = folder.path_join("generated_sheet.png")
        var generated: Dictionary
        if FileAccess.file_exists(sheet_path):
            var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("result.json")))
            if old is Dictionary and old.get("input_sha256", "") == entry["input_sha256"] and old.get("sheet_sha256", "") == FileAccess.get_sha256(sheet_path):
                generated = {"ok":true,"sheet":Image.load_from_file(sheet_path), "cached_pixels":true, "model":old.get("model", "cached"), "engine":old.get("engine", "cached")}
            else:
                entry["error"] = "cache_binding_changed_use_new_evidence_directory"
                write_json(folder.path_join("blocked_cache_attempt.json"), entry)
                summary["cases"].append(entry)
                worker.queue_free()
                await process_frame
                continue
        else:
            generated = await worker.redraw_batch(reference, briefs, test["style"])
        if generated.get("ok", false) and generated.get("sheet") is Image:
            var sheet: Image = generated["sheet"]
            sheet.save_png(sheet_path)
            var split: Dictionary = worker.split_batch(sheet, 2, 1)
            if split.get("ok", false):
                for i in range(2):
                    split["images"][i].save_png(folder.path_join("drawing_%02d.png" % i))
                entry["complete"] = true
                entry["sheet_sha256"] = FileAccess.get_sha256(sheet_path)
                entry["model"] = generated.get("model", "cached real model pixels")
                entry["engine"] = generated.get("engine", "cached")
        else:
            entry["error"] = generated.get("error", "redraw_failed")
            entry["engines"] = generated.get("engines", {})
        known_engines = worker.engine_status.duplicate(true)
        write_json(folder.path_join("result.json"), entry)
        summary["cases"].append(entry)
        print("REAL_CASE ", JSON.stringify(entry))
        worker.queue_free()
        await process_frame
    write_json(DEST.path_join("summary.json"), summary)
    quit(0)
