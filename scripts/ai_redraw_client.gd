extends Node
## HTTP client for a REAL external diffusion image-to-image inference server.
## This is NOT offline on-device AI. User must opt in to upload reference.
signal redraw_finished(result: Dictionary)

@export var endpoint: String = "http://127.0.0.1:8765/redraw"
var busy: bool = false

func redraw(reference: Image, description: String, action: String, strength: float = 0.55, seed: int = 1234, upload_approved: bool = false) -> void:
    if busy:
        redraw_finished.emit({"ok": false, "reason": "busy"})
        return
    if not upload_approved:
        redraw_finished.emit({"ok": false, "reason": "reference_upload_requires_consent"})
        return
    if reference == null or reference.is_empty():
        redraw_finished.emit({"ok": false, "reason": "missing_reference"})
        return
    if not endpoint.begins_with("https://") and not endpoint.begins_with("http://127.0.0.1:"):
        redraw_finished.emit({"ok": false, "reason": "https_required_for_remote_server"})
        return
    var boundary: String = "mobilei2v-boundary-2026"
    var body: PackedByteArray = PackedByteArray()
    _append_field(body, boundary, "prompt", description)
    _append_field(body, boundary, "action", action)
    _append_field(body, boundary, "strength", str(clampf(strength, 0.1, 0.95)))
    _append_field(body, boundary, "seed", str(seed))
    body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"reference\"; filename=\"reference.png\"\r\nContent-Type: image/png\r\n\r\n" % boundary).to_utf8_buffer())
    body.append_array(reference.save_png_to_buffer())
    body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
    var request := HTTPRequest.new()
    request.timeout = 180.0
    add_child(request)
    busy = true
    request.request_completed.connect(_on_completed.bind(request), CONNECT_ONE_SHOT)
    var err: Error = request.request_raw(endpoint, ["Content-Type: multipart/form-data; boundary=" + boundary], HTTPClient.METHOD_POST, body)
    if err != OK:
        busy = false
        request.queue_free()
        redraw_finished.emit({"ok": false, "reason": "request_start_failed", "error": err})

func _append_field(body: PackedByteArray, boundary: String, name: String, value: String) -> void:
    body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, name, value]).to_utf8_buffer())

func _on_completed(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray, request: HTTPRequest) -> void:
    busy = false
    request.queue_free()
    if result != HTTPRequest.RESULT_SUCCESS or status != 200:
        redraw_finished.emit({"ok": false, "reason": "inference_unavailable", "http_status": status, "request_result": result})
        return
    var frame := Image.new()
    var err: Error = frame.load_png_from_buffer(bytes)
    if err != OK:
        redraw_finished.emit({"ok": false, "reason": "invalid_generated_png"})
        return
    redraw_finished.emit({"ok": true, "image": frame, "generative_redraw": true, "identity_verified": false, "engine": "remote_diffusers_img2img"})
