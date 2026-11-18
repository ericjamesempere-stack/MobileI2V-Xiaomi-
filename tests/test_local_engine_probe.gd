extends SceneTree
class TestPipeline extends "res://scripts/universal_board_pipeline.gd":
    var build_calls: int = 0
    func _ready() -> void:
        worker=load("res://scripts/local_studio_generator.gd").new()
        worker.vision_base=OS.get_environment("KARMA_PROBE_SERVER")
        worker.drawing_base=worker.vision_base
        add_child(worker)
    func build_boards(_reference: Image,_story: String,_seconds: float,_style: String,_folder: String,_maximum: int=24) -> Dictionary:
        build_calls+=1
        return {"ok":false,"stage":"analysis","error":"SHOULD_NOT_RUN"}
class TestBoard extends "res://scripts/storyboard.gd":
    func _make_universal_pipeline() -> Node:
        return TestPipeline.new()
    func _make_drawing_worker() -> Node:
        var worker: Node=super._make_drawing_worker()
        worker.vision_base=OS.get_environment("KARMA_PROBE_SERVER")
        worker.drawing_base=worker.vision_base
        return worker
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var scenario: String=OS.get_environment("KARMA_PROBE_SCENARIO")
    var save: String="user://mobilei2v_storyboard_v23.json"
    var existed: bool=FileAccess.file_exists(save)
    var backup: PackedByteArray=FileAccess.get_file_as_bytes(save) if existed else PackedByteArray()
    var board:=TestBoard.new()
    root.add_child(board)
    board.local_mode.set_pressed_no_signal(true)
    board.local_auth_input.text="private-probe-token"
    await board._check_local_engines()
    assert(not board.ai_running)
    assert(board.last_local_probe["cloud_requests"]==0 and not board.last_local_probe["inference_verified"])
    assert(not JSON.stringify(board.last_local_probe).contains("private-probe-token"))
    assert(board.last_local_probe["ok"]==(scenario=="ready"),board.status.text)
    if scenario=="ready":
        assert(board.last_local_probe["vision"]["model"]=="fixture-vision")
        assert(not board.last_local_probe["vision"]["vision_capability_verified"])
        assert(not board.last_local_probe["drawing"]["img2img_verified"])
    else:
        await board._image_chosen("res://validation/v54-poses/reference.png")
        var reference_path: String=board.imported_path
        var digest: String=FileAccess.get_sha256(reference_path)
        board.action_input.text="SYNTHETIC local setup failure must not start inference."
        var previous_pipeline: Node = board.universal_pipeline
        for i in range(3):
            await board._draw_remote_story()
            assert(board.universal_pipeline == previous_pipeline, "A failed probe must preserve the active project's engine")
            assert(board.imported_path==reference_path and FileAccess.get_sha256(reference_path)==digest)
            assert(not board.ai_running and not board._has_current_review())
    var local_source: String=FileAccess.get_file_as_string("res://scripts/local_studio_generator.gd")
    assert(local_source.contains("maxi(input.get_width(), input.get_height()) > 768"))
    assert(local_source.contains("analysis_image = input.duplicate()"))
    assert(local_source.contains("http.timeout = minf(timeout_seconds, 75.0)"))
    var worker: Node=board._make_drawing_worker()
    root.add_child(worker)
    assert(not worker.select_active_model({"data":[{"id":"text"},{"id":"vision"}]})["ok"])
    assert(not worker.select_active_model({"data":[{"id":123}]})["ok"])
    var image:=Image.create(512,512,false,Image.FORMAT_RGB8)
    image.fill(Color.RED)
    var png: PackedByteArray=image.save_png_to_buffer()
    var body: Dictionary={"type":"complete","format":"png","width":512,"height":512,"channels":3,"image":Marshalls.raw_to_base64(png)}
    var result: Dictionary=worker.decode_local_drawing("event: complete\ndata: "+JSON.stringify(body)+"\n\n")
    assert(result["ok"] and result["image"].get_pixel(10,10).is_equal_approx(Color.RED))
    body["width"]=1024
    assert(not worker.decode_local_drawing("data: "+JSON.stringify(body)+"\n\n")["ok"])
    body["width"]=512
    body["format"]="unsupported"
    assert(not worker.decode_local_drawing("data: "+JSON.stringify(body)+"\n\n")["ok"])
    worker.queue_free()
    board.queue_free()
    await process_frame
    if existed:
        var f:=FileAccess.open(save,FileAccess.WRITE)
        f.store_buffer(backup)
        f.close()
    else:
        DirAccess.remove_absolute(save)
    print("LOCAL_ENGINE_PROBE_OK "+scenario+": HTTP metadata only, no inference proof, no auto approval")
    quit(0)
