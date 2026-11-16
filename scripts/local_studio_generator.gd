extends "res://scripts/hf_studio_generator.gd"
# Adapters for existing on-device engines. No engine, model or cloud fallback is
# bundled here. Loopback-only requests must never use a development HTTP proxy.
var vision_base: String = "http://127.0.0.1:8080"
var drawing_base: String = "http://127.0.0.1:8081"
var local_token: String = ""
var local_model: String = ""
var use_opencl: bool = false
const LOCAL_REVISION := "mnn-localdream-v1"

func vision_provider_id() -> String:
    return LOCAL_REVISION + ":" + vision_base

func max_batch_size(_style: String) -> int:
    return 1 # Sequential generation bounds inference memory use.

func _loopback(base: String) -> bool:
    var regex := RegEx.new()
    regex.compile("^http://127\\.0\\.0\\.1:([0-9]{1,5})$")
    var matched: RegExMatch = regex.search(base)
    return matched != null and int(matched.get_string(1)) > 0 and int(matched.get_string(1)) <= 65535

func _local_request(base: String, path: String, payload: Dictionary = {}, get_request: bool = false) -> Dictionary:
    if not _loopback(base) or path not in ["/v1/models", "/v1/chat/completions", "/generate"]:
        return {"ok": false, "error": "Adresse locale invalide. Aucun fichier envoyé."}
    var http := HTTPRequest.new()
    http.timeout = 900.0
    http.body_size_limit = 18000000
    add_child(http)
    var headers: PackedStringArray = ["Content-Type: application/json"]
    if base == vision_base and not local_token.is_empty():
        headers.append("Authorization: Bearer " + local_token)
    var error: Error = http.request(base + path, headers, HTTPClient.METHOD_GET if get_request else HTTPClient.METHOD_POST, "" if get_request else JSON.stringify(payload))
    if error != OK:
        http.queue_free()
        return {"ok": false, "error": "Connexion au moteur local impossible."}
    var response: Array = await http.request_completed
    http.queue_free()
    if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
        return {"ok": false, "http_status": int(response[1]), "error": "Moteur local non prêt (HTTP %d). Ouvre et charge le modèle dans %s. Aucun service en ligne n'est appelé." % [int(response[1]), "MNN Chat" if base == vision_base else "Local Dream"]}
    return {"ok": true, "body": (response[3] as PackedByteArray).get_string_from_utf8()}

func _vision_request(images: Array[Image], prompt: String) -> Dictionary:
    # MNN Chat exposes an OpenAI-compatible API. Select an actually loaded
    # model, never assume that a model with vision is bundled in this app.
    if local_model.is_empty():
        var discovery: Dictionary = await _local_request(vision_base, "/v1/models", {}, true)
        if not discovery.get("ok", false):
            return discovery
        var models: Variant = JSON.parse_string(discovery["body"])
        if not models is Dictionary or not models.get("data") is Array or models["data"].is_empty() or not models["data"][0] is Dictionary:
            return {"ok": false, "error": "Charge un modèle acceptant les images dans MNN Chat et active son API locale."}
        local_model = str(models["data"][0].get("id", ""))
    if local_model.is_empty():
        return {"ok": false, "error": "Aucun modèle local sélectionné."}
    var content: Array = [{"type": "text", "text": prompt}]
    for input in images:
        content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + _encode_input(input)}})
    var result: Dictionary = await _local_request(vision_base, "/v1/chat/completions", {"model": local_model, "messages": [{"role": "user", "content": content}], "stream": false, "max_tokens": 4096, "temperature": 0.1})
    if not result.get("ok", false):
        return result
    var decoded: Variant = JSON.parse_string(result["body"])
    if not decoded is Dictionary or not decoded.get("choices") is Array or decoded["choices"].is_empty() or not decoded["choices"][0] is Dictionary:
        return {"ok": false, "error": "Réponse du modèle local illisible."}
    var choice: Dictionary = decoded["choices"][0]
    if choice.get("finish_reason", "") == "length" or not choice.get("message") is Dictionary or not choice["message"].get("content") is String:
        return {"ok": false, "error": "Analyse locale incomplète. Réduis la longueur de l'histoire."}
    var raw: String = choice["message"]["content"]
    if raw.contains("</think>"):
        raw = raw.substr(raw.rfind("</think>") + 8)
    return {"ok": true, "data": [{"role": "assistant", "status": "done", "content": [{"type": "text", "content": raw}]}]}

func _generation_payload(reference: Image, instruction: String, style: String, variation: bool) -> Dictionary:
    var image: Image = reference if repair_target == null else repair_target
    var copy: Image = image.duplicate()
    var ratio: float = 512.0 / float(maxi(copy.get_width(), copy.get_height()))
    copy.resize(maxi(1, roundi(copy.get_width() * ratio)), maxi(1, roundi(copy.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
    copy.convert(Image.FORMAT_RGB8)
    var canvas := Image.create(512, 512, false, Image.FORMAT_RGB8)
    canvas.fill(image.get_pixel(0, 0))
    canvas.blit_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), Vector2i((512 - copy.get_width()) / 2, (512 - copy.get_height()) / 2))
    var directive: String = instruction + " " + _style_instruction(style) + " Preserve the reference identities and anatomy. "
    if not scene_registry.is_empty():
        directive += JSON.stringify({"entities": scene_registry.get("entities", []), "relations": scene_registry.get("relations", [])})
    return {"image": _encode_input(canvas), "prompt": directive, "negative_prompt": "unrequested subjects, duplicate subject, invented body parts, changed identity, text, watermark", "width": 512, "height": 512, "steps": 20, "cfg": 7.5, "seed": randi() if variation else 1234, "scheduler": "dpm", "denoise_strength": 0.6, "use_opencl": use_opencl, "show_diffusion_process": false}

func decode_local_drawing(body: String) -> Dictionary:
    for block in body.replace("\r\n", "\n").split("\n\n"):
        var payload: String = ""
        for line in block.split("\n"):
            if line.begins_with("data:"):
                payload += line.substr(5).strip_edges()
        var value: Variant = JSON.parse_string(payload)
        if not value is Dictionary:
            continue
        if value.get("type", "") == "error":
            return {"ok": false, "error": "Le moteur local a interrompu le dessin. L'ancien est conservé. " + str(value.get("message", ""))}
        if value.get("type", "") != "complete":
            continue
        for key in ["width", "height", "channels"]:
            if not (value.get(key) is int or value.get(key) is float) or float(value[key]) != float(int(value[key])):
                return {"ok": false, "error": "Dimensions du dessin local invalides."}
        var w: int = int(value["width"])
        var h: int = int(value["height"])
        if w < 512 or h < 512 or w > 1024 or h > 1024 or int(value["channels"]) != 3 or not value.get("image") is String or value["image"].length() > 5000000:
            return {"ok": false, "error": "Format du dessin local incompatible."}
        var bytes: PackedByteArray = Marshalls.base64_to_raw(value["image"])
        if bytes.size() != w * h * 3:
            return {"ok": false, "error": "Pixels du dessin local incomplets."}
        return {"ok": true, "image": Image.create_from_data(w, h, false, Image.FORMAT_RGB8, bytes), "engine": "Local Dream MNN", "identity_verified": false}
    return {"ok": false, "error": "Le moteur local n'a pas livré de dessin complet."}

func redraw(reference: Image, instruction: String, style: String, _previous: Image = null, variation: bool = false) -> Dictionary:
    if reference == null or reference.is_empty():
        return {"ok": false, "error": "Image de référence manquante."}
    # This API only accepts one source image; no silent approximation of the
    # separate multi-image style-reference capability of the remote adapter.
    if style_reference != null and not style_reference.is_empty():
        return {"ok": false, "error": "Le moteur local ne prend pas en charge une référence de style séparée. Retire-la pour ce mode."}
    var result: Dictionary = await _local_request(drawing_base, "/generate", _generation_payload(reference, instruction, style, variation))
    if not result.get("ok", false):
        return result
    return decode_local_drawing(result["body"])

func redraw_batch(reference: Image, briefs: Array, style: String, previous: Image = null) -> Dictionary:
    if briefs.size() != 1 or not briefs[0] is Dictionary:
        return {"ok": false, "error": "Le moteur local traite un dessin à la fois."}
    var result: Dictionary = await redraw(reference, str(briefs[0].get("instruction", "")), style, previous)
    if result.get("ok", false):
        result["images"] = [result["image"]]
    return result

func configure_local(token: String) -> void:
    local_token = token.strip_edges()

func create_reference(description: String, style: String) -> Dictionary:
    if description.strip_edges().is_empty():
        return {"ok": false, "error": "Décris d'abord le sujet à créer."}
    var payload: Dictionary = {"prompt": build_reference_prompt(description, style), "negative_prompt": "unrequested human body, text, watermark, unrequested subjects", "width": 512, "height": 512, "steps": 20, "cfg": 7.5, "seed": 1234, "scheduler": "dpm", "use_opencl": use_opencl}
    var result: Dictionary = await _local_request(drawing_base, "/generate", payload)
    return decode_local_drawing(result["body"]) if result.get("ok", false) else result
