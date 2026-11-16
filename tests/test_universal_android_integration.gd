extends SceneTree
# Integration of the production Android screen and pipeline. Remote inference and
# MediaCodec are substituted; ffmpeg produces and ffprobe inspects a REAL MP4.
class FixtureWorker extends "res://scripts/hf_studio_generator.gd":
    var analysis_calls: int = 0
    var generated: int = 0
    var repairs: int = 0
    var reviews: int = 0
    var stop_generation: bool = false
    var fail_analysis: bool = false
    var fail_review: bool = false
    func _upload_images(_base: String, images: Array[Image]) -> Dictionary:
        return {"ok": true, "files": [{"path": "SIMULATED-upload", "meta": {"_type": "gradio.FileData"}}]}
    func _call_api(_base: String, _api: String, _data: Array) -> Dictionary:
        analysis_calls += 1
        if fail_analysis:
            return {"ok": false, "error": "SIMULATED vision outage"}
        var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/universal_a_annotation.json"))
        return {"ok": true, "data": [{"role": "assistant", "status": "done", "content": [{"type": "text", "content": JSON.stringify(scene)}]}]}
    func drawing(index: int) -> Image:
        var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
        image.fill(Color.WHITE)
        image.fill_rect(Rect2i(16 + index * 25, 150, 100, 200), Color("a54030"))
        return image
    func redraw_batch(_reference: Image, briefs: Array, _style: String, _previous: Image = null) -> Dictionary:
        if stop_generation and generated > 0:
            return {"ok": false, "error": "SIMULATED quota"}
        var images: Array[Image] = []
        for brief in briefs:
            images.append(drawing(generated))
            generated += 1
        return {"ok": true, "images": images}
    func assess_keyposes(_reference: Image, _frames: Array[Image], expected: Array) -> Dictionary:
        reviews += expected.size()
        if fail_review:
            return {"ok": false, "error": "SIMULATED review unavailable", "fidelity_verified": false}
        var rows: Array = []
        for i in range(expected.size()):
            rows.append({"index": i, "identity_match": true, "count_match": true, "action_match": true, "environment_match": true, "perspective_match": true, "uncertain": false, "defects": []})
        return {"ok": true, "review": {"frames": rows}, "review_origin": "live_vision_model"}
    func _redraw_qwen(_reference: Image, _story: String, _style: String, _previous: Image, _variation: bool) -> Dictionary:
        assert(repair_target != null and not scene_registry.is_empty())
        repairs += 1
        return {"ok": true, "image": drawing(9), "model": "SIMULATED targeted repair"}

class Pipeline extends "res://scripts/universal_board_pipeline.gd":
    func _ready() -> void:
        worker = FixtureWorker.new()
        add_child(worker)

class Recorder extends RefCounted:
    var folder: String
    var frames: Array = []
    func begin(_output: String, _width: int, _height: int, _fps: int) -> bool:
        folder = "user://android_integration_%d" % Time.get_ticks_usec()
        return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK
    func push_frame_rgba(data: PackedByteArray) -> bool:
        frames.append(hash(data))
        var image := Image.create_from_data(720, 1280, false, Image.FORMAT_RGBA8, data)
        image.resize(96, 160)
        return image.save_png(folder.path_join("frame_%04d.png" % (frames.size() - 1))) == OK
    func finish() -> String:
        var output: String = ProjectSettings.globalize_path(folder.path_join("integration.mp4"))
        var logs: Array = []
        var code: int = OS.execute("ffmpeg", ["-hide_banner", "-loglevel", "error", "-y", "-framerate", "30", "-i", ProjectSettings.globalize_path(folder.path_join("frame_%04d.png")), "-c:v", "libx264", "-threads", "1", "-pix_fmt", "yuv420p", output], logs, true)
        assert(code == 0, str(logs))
        return output
    func abort() -> void:
        assert(false, "Unexpected encoder abort")

class Exporter extends "res://scripts/export_mp4.gd":
    var recorder: Recorder
    func _get_encoder() -> Object:
        return recorder

class Board extends "res://scripts/storyboard.gd":
    var recorder := Recorder.new()
    var encoder_calls: int = 0
    func _make_universal_pipeline() -> Node:
        return Pipeline.new()
    func _mp4_encoder_available() -> bool:
        return true
    func _make_mp4_exporter() -> Node:
        encoder_calls += 1
        var exporter := Exporter.new()
        exporter.recorder = recorder
        return exporter

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var save: String = "user://mobilei2v_storyboard_v23.json"
    var existed: bool = FileAccess.file_exists(save)
    var backup: PackedByteArray = FileAccess.get_file_as_bytes(save) if existed else PackedByteArray()
    var board := Board.new()
    root.add_child(board)
    await board._image_chosen("res://validation/v54-poses/reference.png")
    board.style_reference_path = ""
    board.custom_style_input.text = ""
    board.drawing_style.select(0)
    board.action_input.text = "Le personnage court, trébuche puis tombe. SIMULATED integration %d" % Time.get_ticks_usec()
    board.duration_input.value = 5
    board.ai_drawings_count.value = 24
    await board._friendly_generate()
    assert(board.universal_plan.get("semantic_analysis", false), board.status.text)
    assert(board.sources.size() == 8 and board.required_drawing_count == 8)
    assert(board.universal_pipeline.worker.analysis_calls == 1)
    assert(board.universal_pipeline.worker.generated == 8)
    assert(board.plan.size() == 150 and board.wizard_step == 2)
    assert(board.contact_sheet.texture != null and not board._has_current_review())
    await board._friendly_export()
    assert(board.encoder_calls == 0)
    board._show_drawing_review()
    for i in range(8):
        board.review_index = i
        board._review_choose(true)
    board.review_check.set_pressed(true)
    assert(board._has_current_review(), board.status.text)
    board.review_index = 3
    board._review_choose(false)
    board.review_check.set_pressed(true)
    assert(not board._has_current_review())
    await board._friendly_export()
    assert(board.encoder_calls == 0)
    var hashes: Array = []
    for path in board.paths:
        hashes.append(FileAccess.get_sha256(path))
    var worker: FixtureWorker = board.universal_pipeline.worker
    var review_count: int = worker.reviews
    await board._regenerate_reviewed_drawing()
    assert(worker.repairs == 1 and worker.reviews == review_count + 1)
    assert(not board.accepted[3] and not board._has_current_review())
    for i in range(8):
        assert((FileAccess.get_sha256(board.paths[i]) == hashes[i]) == (i != 3))
    board._review_choose(true)
    board.review_check.set_pressed(true)
    assert(board._has_current_review())
    # The approved physical timeline is passed unchanged to the real exporter.
    var canvas: Node = load("res://scripts/export_mp4.gd").new()
    var expected_hashes: Array = []
    for source in board.sources:
        var image: Image = canvas._fit_canvas(source.get_image())
        expected_hashes.append(hash(image.get_data()))
    canvas.free()
    var timeline: Array = board.plan.duplicate()
    board.review_dialog.hide()
    await board._friendly_export()
    assert(board.encoder_calls == 1 and board.recorder.frames.size() == 150)
    for i in range(150):
        assert(board.recorder.frames[i] == expected_hashes[timeline[i]], "Export must respect each planned timestamp")
    assert(board.session_agent.state["agents"]["video"] == "encoded_native")
    var probe: Array = []
    assert(OS.execute("ffprobe", ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=nb_frames,duration", "-of", "json", board.session_agent.state["video_output"]], probe) == 0)
    var video: Dictionary = JSON.parse_string(str(probe[0]))
    assert(int(video["streams"][0]["nb_frames"]) == 150)
    assert(is_equal_approx(float(video["streams"][0]["duration"]), 5.0))
    # Reopening preserves bindings and timing, but requires fresh confirmation.
    board._load_saved()
    assert(board.universal_plan["keyposes"] == 8 and board.plan == timeline)
    assert(not board._has_current_review())
    assert(board._universal_ready_for_review())
    board.review_check.set_pressed(true)
    assert(board._has_current_review())
    board.action_input.text += " changed"
    assert(not board._has_current_review())
    board._save()
    # Failed real-analysis substitute must retain current drawings, never fall back.
    hashes.clear()
    for path in board.paths:
        hashes.append(FileAccess.get_sha256(path))
    board.universal_pipeline.worker.fail_analysis = true
    # New pipeline factory is replaced below by a failure mode on the next instance.
    var failing := FailingBoard.new()
    root.add_child(failing)
    failing.action_input.text += " analysis outage"
    await failing._friendly_generate()
    assert(not failing.last_ai_sequence_ok and failing.universal_pipeline.worker.generated == 0)
    for i in range(8):
        assert(FileAccess.get_sha256(failing.paths[i]) == hashes[i])
    assert(not failing._has_current_review())
    failing.free()
    # An analysed scene that exceeds the user's budget does not consume drawing GPU.
    board.ai_drawings_count.value = 2
    board.action_input.text += " budget"
    await board._friendly_generate()
    assert(board.status.text.contains("limite") and board.universal_pipeline.worker.generated == 0)
    assert(board.sources.size() == 8 and not board._has_current_review())
    board.ai_drawings_count.value = 24
    board._save()
    var partial := PartialBoard.new()
    root.add_child(partial)
    partial.action_input.text += " partial"
    await partial._friendly_generate()
    assert(partial.sources.size() > 0 and partial.sources.size() < partial.required_drawing_count)
    partial._show_drawing_review()
    for i in range(partial.sources.size()):
        partial.review_index = i
        partial._review_choose(true)
    partial.review_check.set_pressed(true)
    assert(not partial._has_current_review())
    await partial._friendly_export()
    assert(partial.encoder_calls == 0)
    partial.free()
    var unverified := ReviewOutageBoard.new()
    root.add_child(unverified)
    unverified.action_input.text += " review-outage"
    await unverified._friendly_generate()
    assert(unverified.sources.size() == 8 and not unverified.universal_quality["fidelity_verified"])
    unverified._show_drawing_review()
    for i in range(8):
        unverified.review_index = i
        unverified._review_choose(true)
    unverified.review_check.set_pressed(true)
    await unverified._friendly_export()
    assert(not unverified._has_current_review() and unverified.encoder_calls == 0)
    # Explicitly importing another board must not inherit the strict registry
    # of a previous project, nor its approval or session journal.
    var import_folder: String = "user://legacy_board_%d" % Time.get_ticks_usec()
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(import_folder)) == OK)
    var drawing: Image = unverified.sources[0].get_image()
    assert(drawing.save_png(import_folder.path_join("a.png")) == OK)
    assert(drawing.save_png(import_folder.path_join("b.png")) == OK)
    await unverified._drawings_folder_selected(import_folder)
    assert(unverified.universal_folder.is_empty() and unverified.universal_plan.is_empty())
    assert(unverified.sources.size() == 2 and unverified.session_agent == null)
    assert(not unverified._has_current_review())
    unverified.free()
    board.free()
    if existed:
        var file := FileAccess.open(save, FileAccess.WRITE)
        file.store_buffer(backup)
        file.close()
    else:
        DirAccess.remove_absolute(save)
    print("UNIVERSAL_ANDROID_INTEGRATION_OK: production screen -> SIMULATED vision -> strict plan -> poses -> contact sheet -> keep/reject/targeted redo -> mandatory approval -> real ffmpeg MP4 150 frames / 5s, exact timeline; restore and outage block; no Xiaomi/MediaCodec test")
    quit(0)

class FailingPipeline extends Pipeline:
    func _ready() -> void:
        super._ready()
        worker.fail_analysis = true
class FailingBoard extends Board:
    func _make_universal_pipeline() -> Node:
        return FailingPipeline.new()

class PartialPipeline extends Pipeline:
    func _ready() -> void:
        super._ready()
        worker.stop_generation = true
class PartialBoard extends Board:
    func _make_universal_pipeline() -> Node:
        return PartialPipeline.new()
class ReviewOutagePipeline extends Pipeline:
    func _ready() -> void:
        super._ready()
        worker.fail_review = true
class ReviewOutageBoard extends Board:
    func _make_universal_pipeline() -> Node:
        return ReviewOutagePipeline.new()
