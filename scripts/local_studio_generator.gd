extends "res://scripts/hf_studio_generator.gd"
# Adapters for existing on-device engines. No engine, model or cloud fallback is
# bundled here. Loopback-only requests must never use a development HTTP proxy.
var vision_base: String = "http://127.0.0.1:8080"
var drawing_base: String = "http://127.0.0.1:8081"
var local_token: String = ""
var local_model: String = ""
var use_opencl: bool = false
const LOCAL_REVISION := "mnn-localdream-v3-clip-prompts"
var drawing_probe_base: String = ""
var last_probe: Dictionary = {}

func vision_provider_id() -> String:
    # Connectivity changes do not invalidate existing checked drawings when
    # reopening a project before the engine has been contacted again.
    return "mnn-localdream-v1:" + vision_base

func inference_context_id() -> String:
    # The retry budget, unlike cached visual reviews, must follow the active
    # model so selecting a different model can resolve an inference failure.
    return LOCAL_REVISION + ":" + vision_base + ":" + local_model

func max_batch_size(_style: String) -> int:
    return 1 # Sequential generation bounds inference memory use.

func _loopback(base: String) -> bool:
    var regex := RegEx.new()
    regex.compile("^http://127\\.0\\.0\\.1:([0-9]{1,5})$")
    var matched: RegExMatch = regex.search(base)
    return matched != null and int(matched.get_string(1)) > 0 and int(matched.get_string(1)) <= 65535

func _local_request(base: String, path: String, payload: Dictionary = {}, get_request: bool = false, timeout_seconds: float = 900.0) -> Dictionary:
    if not _loopback(base) or path not in ["/v1/models", "/v1/chat/completions", "/generate", "/health", "/tokenize"]:
        return {"ok": false, "error": "Adresse locale invalide. Aucun fichier envoyé."}
    var http := HTTPRequest.new()
    # Vision analysis must release the Android UI promptly if MNN stops responding.
    # Preserve the longer budget for actual image generation, which can be slow.
    http.timeout = minf(timeout_seconds, 75.0) if path == "/v1/chat/completions" else timeout_seconds
    http.max_redirects = 0 # Never forward a photo or token outside loopback.
    http.body_size_limit = 18000000
    add_child(http)
    var headers: PackedStringArray = ["Content-Type: application/json"]
    var vision_call: bool = path.begins_with("/v1/")
    if vision_call and base == vision_base and not local_token.is_empty():
        headers.append("Authorization: Bearer " + local_token)
    var error: Error = http.request(base + path, headers, HTTPClient.METHOD_GET if get_request else HTTPClient.METHOD_POST, "" if get_request else JSON.stringify(payload))
    if error != OK:
        http.queue_free()
        return {"ok": false, "endpoint": path, "request_error": int(error), "error": "Requête locale impossible : " + base + path + " (erreur %d). Aucun fichier envoyé en ligne." % int(error)}
    var response: Array = await http.request_completed
    http.queue_free()
    if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
        var guidance: String = "Copie la clé du service API MNN Chat dans le champ privé de KARMA ONE." if vision_call and int(response[1]) in [401, 403] else "Ouvre %s, charge son modèle et laisse son service actif." % ("MNN Chat" if vision_call else "Local Dream")
        return {"ok": false, "http_status": int(response[1]), "network_result": int(response[0]), "endpoint": path, "error": "Moteur local indisponible : %s%s (HTTP %d, réseau %d). %s Aucun service en ligne n'est appelé." % [base, path, int(response[1]), int(response[0]), guidance]}
    return {"ok": true, "body": (response[3] as PackedByteArray).get_string_from_utf8()}

func select_active_model(models: Variant) -> Dictionary:
    if not models is Dictionary or not models.get("data") is Array:
        return {"ok": false, "error": "La liste des modèles MNN est illisible."}
    var ids: Array[String] = []
    for row in models["data"]:
        if not row is Dictionary or not row.get("id") is String or row["id"].strip_edges().is_empty() or row["id"] != row["id"].strip_edges() or row["id"] in ids:
            return {"ok": false, "error": "La liste des modèles MNN contient une entrée invalide."}
        ids.append(row["id"])
    if ids.is_empty():
        return {"ok": false, "error": "Charge un modèle vision dans MNN Chat puis active son API locale."}
    if not local_model.is_empty():
        if local_model not in ids:
            return {"ok": false, "error": "Le modèle MNN a changé. Relance la vérification des moteurs."}
        return {"ok": true, "model": local_model}
    if ids.size() != 1:
        return {"ok": false, "error": "Plusieurs modèles sont annoncés. Active un seul modèle vision dans MNN Chat."}
    return {"ok": true, "model": ids[0]}

func inspect_local_engines(include_vision: bool = true, include_drawing: bool = true) -> Dictionary:
    # GET only: no photo, prompt, token in report, generation or paid fallback.
    var report: Dictionary = {"ok": true, "cloud_requests": 0, "inference_verified": false, "vision": {"status": "not_checked"}, "drawing": {"status": "not_checked"}, "message": ""}
    var failures: Array[String] = []
    if OS.get_name() == "Android" and Engine.has_singleton("MP4Exporter"):
        var native: Object = Engine.get_singleton("MP4Exporter")
        report["android_apps"] = JSON.parse_string(str(native.call("local_engine_installation_status")))
    if include_vision:
        var response: Dictionary = await _local_request(vision_base, "/v1/models", {}, true, 4.0)
        var parsed := JSON.new()
        var selection: Dictionary = {"ok": false, "error": response.get("error", "Réponse MNN illisible.")}
        if response.get("ok", false) and parsed.parse(response["body"]) == OK:
            selection = select_active_model(parsed.data)
        if selection.get("ok", false):
            local_model = selection["model"]
            report["vision"] = {"status": "active_model_listed", "model": local_model, "vision_capability_verified": false}
        else:
            report["ok"] = false
            report["vision"] = {"status": "unavailable", "http_status": response.get("http_status", 0), "network_result": response.get("network_result", -1), "endpoint": response.get("endpoint", "")}
            failures.append(selection["error"])
    if include_drawing:
        var response: Dictionary = await _local_request(drawing_base, "/health", {}, true, 4.0)
        if response.get("ok", false):
            drawing_probe_base = drawing_base
            # Upstream /health returns HTTP 200 with an empty body. It does
            # not prove which model is loaded or whether img2img is enabled.
            report["drawing"] = {"status": "http_reachable", "model_verified": false, "img2img_verified": false}
        else:
            drawing_probe_base = ""
            report["ok"] = false
            report["drawing"] = {"status": "unavailable", "http_status": response.get("http_status", 0), "network_result": response.get("network_result", -1), "endpoint": response.get("endpoint", "")}
            failures.append(response.get("error", "Ouvre Local Dream et charge un modèle CPU avec img2img."))
    var apps: Variant = report.get("android_apps", {})
    if apps is Dictionary and not apps.is_empty():
        if include_drawing and apps.get("io.github.xororz.localdream", {}).get("installed", true) == false:
            failures.append("Local Dream n'est pas installé sur ce téléphone. Utilise le lien d'installation dans les options.")
            report["ok"] = false
        if include_vision and apps.get("com.alibaba.mnnllm.android", {}).get("installed", true) == false and apps.get("com.alibaba.mnnllm.android.release", {}).get("installed", true) == false:
            failures.append("MNN Chat n'est pas installé sur ce téléphone. Utilise le lien d'installation dans les options.")
            report["ok"] = false
    report["message"] = "Connexion locale vérifiée. L'analyse et les dessins doivent encore réussir avec les modèles chargés." if failures.is_empty() else " ".join(failures)
    last_probe = report.duplicate(true)
    return report

func _ensure_drawing_service() -> Dictionary:
    if drawing_probe_base == drawing_base:
        return {"ok": true}
    var result: Dictionary = await inspect_local_engines(false, true)
    return {"ok": result["ok"], "error": result["message"], "http_status": result["drawing"].get("http_status", 0), "network_result": result["drawing"].get("network_result", -1)}

func _vision_request(images: Array[Image], prompt: String) -> Dictionary:
    # MNN Chat exposes an OpenAI-compatible API. Select an actually loaded
    # model, never assume that a model with vision is bundled in this app.
    if local_model.is_empty():
        var discovery: Dictionary = await inspect_local_engines(true, false)
        if not discovery.get("ok", false):
            return {"ok": false, "error": discovery["message"], "http_status": discovery["vision"].get("http_status", 0), "network_result": discovery["vision"].get("network_result", -1)}
    if local_model.is_empty():
        return {"ok": false, "error": "Aucun modèle local sélectionné."}
    var content: Array = [{"type": "text", "text": prompt}]
    for input in images:
        # Downsample only the analysis copy: the original photo remains untouched
        # for identity checks, drawing and export. Bound image-token and upload cost.
        var analysis_image: Image = input
        if maxi(input.get_width(), input.get_height()) > 768:
            analysis_image = input.duplicate()
            var scale_factor: float = 768.0 / float(maxi(input.get_width(), input.get_height()))
            analysis_image.resize(maxi(1, roundi(input.get_width() * scale_factor)), maxi(1, roundi(input.get_height() * scale_factor)), Image.INTERPOLATE_LANCZOS)
        content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + _encode_input(analysis_image)}})
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
    if reference_contract.get("ok", false):
        directive += " " + " ".join(reference_contract.get("constraints", []))
    return {"image": _encode_input(canvas), "prompt": directive, "negative_prompt": "unrequested subjects, duplicate subject, invented body parts, changed identity, text, watermark", "width": 512, "height": 512, "steps": 20, "cfg": 7.5, "seed": randi() if variation else 1234, "scheduler": "dpm", "denoise_strength": 0.6, "use_opencl": use_opencl, "show_diffusion_process": false, "output_format": "png"}

func _compile_local_prompt(reference: Image, instruction: String, style: String) -> Dictionary:
    # SD1.5 consumes CLIP descriptions, not the long editing instructions used
    # by Qwen. Translate/resolve entity IDs with the existing local vision
    # model, then measure the result with the drawing model's own tokenizer.
    # Never blindly truncate the requested action or submit an oversized prompt.
    var context: String = JSON.stringify({"entities": scene_registry.get("entities", []), "relations": scene_registry.get("relations", [])})
    var prompt: String = "Compile a Stable Diffusion CLIP prompt. Return ONLY JSON {\"prompt\":\"...\"}. Write one concise English visual description, ideally under 40 words. Describe the requested physical state FIRST, then the subject appearance and style. Resolve entity IDs to visible subjects. Preserve counts and non-human anatomy; invent nothing. No instructions, JSON, IDs, panel labels or reference to image numbers inside the prompt. If a transition is requested, describe a single state at the specified fraction, not both endpoints together. The picture anchors appearance; the instruction defines the new action. Style: " + _style_instruction(style) + ". Scene: " + context + ". Requested drawing: " + instruction
    if reference_contract.get("ok", false):
        prompt += " Mandatory identity constraints: " + " ".join(reference_contract.get("constraints", []))
    var inputs: Array[Image] = []
    if reference != null and not reference.is_empty():
        inputs.append(reference)
    for attempt in range(2):
        var response: Dictionary = await _vision_request(inputs, prompt)
        if not response.get("ok", false):
            return response
        var raw: String = extract_vision_text(response.get("data", [])).strip_edges()
        var first: int = raw.find("{")
        var last: int = raw.rfind("}")
        var value: Variant = JSON.parse_string(raw.substr(first, last - first + 1)) if first >= 0 and last > first else null
        if not value is Dictionary or not value.get("prompt") is String or value["prompt"].strip_edges().is_empty() or value["prompt"].length() > 1200:
            return {"ok": false, "error": "Le modèle local n'a pas fourni de consigne de dessin exploitable. Tes dessins sont conservés."}
        var compiled: String = value["prompt"].strip_edges()
        var tokenized: Dictionary = await _local_request(drawing_base, "/tokenize", {"prompt": compiled}, false, 10.0)
        if not tokenized.get("ok", false):
            return tokenized
        var tokens: Variant = JSON.parse_string(tokenized["body"])
        if not tokens is Dictionary or not (tokens.get("count") is int or tokens.get("count") is float) or not (tokens.get("max_length") is int or tokens.get("max_length") is float):
            return {"ok": false, "error": "Le moteur local ne permet pas de vérifier la longueur de la consigne."}
        var count: float = float(tokens["count"])
        var limit: float = float(tokens["max_length"])
        if not is_finite(count) or not is_finite(limit) or count < 2 or count > 1000000 or count != floor(count) or limit < 3 or limit > 8192 or limit != floor(limit):
            return {"ok": false, "error": "Mesure de longueur locale invalide."}
        var budget: int = mini(77, int(limit))
        if count <= budget:
            return {"ok": true, "prompt": compiled, "token_count": int(count)}
        prompt += " Your previous prompt was too long (%d tokens; limit %d including special tokens): %s. Rewrite it substantially shorter, preserving the specific action, subjects and counts. Return the same JSON schema." % [int(count), budget, compiled]
    return {"ok": false, "error": "La consigne reste trop longue pour le modèle local. Aucune image tronquée n'est générée ; tes dessins sont conservés."}

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
        var format: String = str(value.get("format", "raw"))
        if format == "png":
            if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
                return {"ok": false, "error": "En-tête PNG local invalide."}
            var header := StreamPeerBuffer.new()
            header.data_array = bytes
            header.big_endian = true
            header.seek(16)
            if header.get_u32() != w or header.get_u32() != h:
                return {"ok": false, "error": "Dimensions PNG locales incohérentes."}
            var decoded := Image.new()
            var error: Error = decoded.load_png_from_buffer(bytes)
            if error != OK or decoded.is_empty() or decoded.get_width() != w or decoded.get_height() != h:
                return {"ok": false, "error": "Image locale compressée invalide ou dimensions incohérentes."}
            decoded.convert(Image.FORMAT_RGB8)
            return {"ok": true, "image": decoded, "engine": "Local Dream MNN", "identity_verified": false}
        if format != "raw":
            return {"ok": false, "error": "Format du dessin local inconnu."}
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
    var service: Dictionary = await _ensure_drawing_service()
    if not service.get("ok", false):
        return service
    var compiled: Dictionary = await _compile_local_prompt(reference, instruction, style)
    if not compiled.get("ok", false):
        return compiled
    var payload: Dictionary = _generation_payload(reference, instruction, style, variation)
    payload["prompt"] = compiled["prompt"]
    var result: Dictionary = await _local_request(drawing_base, "/generate", payload)
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
    var service: Dictionary = await _ensure_drawing_service()
    if not service.get("ok", false):
        return service
    var compiled: Dictionary = await _compile_local_prompt(null, description, style)
    if not compiled.get("ok", false):
        return compiled
    var payload: Dictionary = {"prompt": compiled["prompt"], "negative_prompt": "unrequested human body, text, watermark, unrequested subjects", "width": 512, "height": 512, "steps": 20, "cfg": 7.5, "seed": 1234, "scheduler": "dpm", "use_opencl": use_opencl, "output_format": "png"}
    var result: Dictionary = await _local_request(drawing_base, "/generate", payload)
    return decode_local_drawing(result["body"]) if result.get("ok", false) else result
