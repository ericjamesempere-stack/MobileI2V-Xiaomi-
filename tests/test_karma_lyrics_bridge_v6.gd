extends SceneTree
# Smoke tests for existing V6 bridge: rejects unreviewed and malformed lyric scenes.
func _initialize() -> void:
    var bridge: RefCounted = load("res://scripts/karma_lyrics_sync_bridge_v6.gd").new()
    var folder: String = "user://karma_lyrics_bridge_test"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    var path: String = folder.path_join("manifest.json")
    _assert_error(bridge.load_manifest(path), "manifest_missing")
    _write(path, {"duration": 10.0, "scenes": [{"start": 0.0, "end": 5.0, "lyrics_reviewed": true, "semantic_status": "director_approved", "action_prompt": "Walking"}]})
    _assert_error(bridge.load_manifest(path), "duration_mismatch")
    _write(path, {"duration": 10.0, "scenes": [{"start": 0.0, "end": 5.0, "lyrics_reviewed": true, "semantic_status": "director_approved", "action_prompt": "Walking"}, {"start": 6.0, "end": 10.0, "lyrics_reviewed": true, "semantic_status": "director_approved", "action_prompt": "Running"}]})
    _assert_error(bridge.load_manifest(path), "timeline_gap_or_overlap")
    _write(path, {"duration": 5.0, "scenes": [{"start": 0.0, "end": 5.0, "lyrics_reviewed": false, "semantic_status": "director_approved", "action_prompt": "Walking"}]})
    _assert_error(bridge.load_manifest(path), "lyrics_review_required")
    _write(path, {"duration": 5.0, "scenes": [{"start": 0.0, "end": 5.0, "lyrics_reviewed": true, "semantic_status": "director_approved", "action_prompt": "Walking"}]})
    assert(bridge.load_manifest(path).get("ok", false), "approved manifest must pass")
    var img: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
    var job: Dictionary = bridge.prepare_existing_pipeline_job(path, 0, img, "Anime", folder)
    assert(job.get("ok", false), "approved scene must create job")
    assert(job.get("method") == "build_boards", "must reuse existing pipeline")
    assert(not job.get("ready_for_export", true), "must preserve export gate")
    print("KARMA_LYRICS_BRIDGE_V6_SMOKE_OK")
    quit(0)

func _assert_error(result: Dictionary, code: String) -> void:
    assert(not result.get("ok", false) and result.get("error", "") == code, "expected " + code)

func _write(path: String, data: Dictionary) -> void:
    var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    assert(f != null, "manifest write failed")
    f.store_string(JSON.stringify(data))
    f.close()
