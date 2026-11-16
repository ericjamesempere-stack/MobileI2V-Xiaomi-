extends Node
# Real remote inference. Public services have quotas and can become unavailable.
signal progress(index: int, total: int)
const TEXT_URL = "https://mrfakename-z-image-turbo.hf.space"
const EDIT_URL = "https://prithivmlmods-qwen-image-edit-2511-loras-fast.hf.space"
const ANYPOSE_URL = "https://abidlabs-qwen-image-edit-2511-anypose.hf.space"
const STYLES = {
    "original": ["Style-Transfer", "Keep the exact original drawing style, subject type, appearance, proportions, materials and colors. Preserve only features actually present in the reference."],
    "bd_detail": ["Style-Transfer", "Detailed semi-realistic comic-book illustration, fine controlled linework, articulation appropriate to the subject, individual hair strands and fabric folds only where already present, precise existing accessories, layered painted shadows, rich materials and coherent directional lighting. Preserve recognizable identity. Avoid simplified flat-color cartoon rendering."],
    "cartoon": ["Anime-V2", "2D cartoon animation, clean expressive outlines, flat colors, consistent subject design."],
    "manga": ["Manga-Tone", "Japanese manga illustration, black and white ink, controlled screentones, consistent subject design."],
    "anime": ["Anime-V2", "Japanese anime animation, clean line art and cel shading, consistent subject design."],
    "3d": ["Pixar-Inspired-3D", "Stylized 3D rendered animation, coherent materials, soft studio lighting, consistent subject design."],
    "cinema": ["Anything2Real", "Cinematic realistic image, coherent lighting, physically plausible materials, consistent subject identity."]
}
var last_error: String = ""
var hf_token: String = ""
var engine_status: Dictionary = {}
var style_reference: Image = null
const DETAIL_CACHE_VERSION := "style-guide-v2"

func detailed_layout(style: String) -> bool:
    return style == "bd_detail" or (style_reference != null and not style_reference.is_empty())

func max_batch_size(style: String) -> int:
    return 2 if detailed_layout(style) else 4

func _encode_input(image: Image) -> String:
    var copy: Image = image.duplicate()
    var side: int = maxi(copy.get_width(), copy.get_height())
    if side > 1024:
        var ratio: float = 1024.0 / float(side)
        copy.resize(maxi(1, roundi(copy.get_width() * ratio)), maxi(1, roundi(copy.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
    return Marshalls.raw_to_base64(copy.save_png_to_buffer())

func build_edit_payload(reference: Image, story: String, style: String, previous: Image = null) -> Dictionary:
    var style_text: String = _style_instruction(style)
    if style_reference != null and not style_reference.is_empty() and style != "bd_detail":
        style_text = "Faithfully match the provided style guide: its linework, shading, palette, material detail and lighting. Preserve the subject identity from the main reference."
    var instruction: String = style_text + " Image 1 is the permanent subject reference. " + story
    var images: Array[String] = [_encode_input(reference)]
    var adapter: String = str(STYLES[style][0]) if STYLES.has(style) else "Style-Transfer"
    var style_image: Image = style_reference
    if style_image == null and (style == "original" or style == "bd_detail" or not STYLES.has(style)):
        style_image = reference
    var previous_number: int = 2
    if style_image != null and not style_image.is_empty():
        images.append(_encode_input(style_image))
        adapter = "Style-Transfer"
        instruction += " Image 2 is a permanent visual-style guide ONLY: use its linework, shading, material detail and lighting. Do not copy its subjects, panels, captions, story or poses. Keep the identity and subject type from image 1. Convert image 1 to the style of image 2 while performing only the requested actions."
        previous_number = 3
    if previous != null:
        images.append(_encode_input(previous))
        instruction += " Image %d is temporal context only, not an additional subject or a target pose. Keep identity and background continuity, but render ONLY the new pose requested above." % previous_number
    return {"instruction": instruction, "images": images, "adapter": adapter}

func _http_failure(code: int, network: int) -> Dictionary:
    var kind: String = "quota" if code == 429 else ("authentication" if code == 401 or code == 403 else "transport")
    return {"ok": false, "error_kind": kind, "http_status": code, "error": "Service IA indisponible (HTTP %d, reseau %d)." % [code, network]}

func _call_api(base: String, api: String, data: Array) -> Dictionary:
    var http := _new_http()
    http.timeout = 180.0
    http.body_size_limit = 24000000
    add_child(http)
    var url: String = base + "/gradio_api/call/" + api
    var err: Error = http.request(url, _headers(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"data": data}))
    if err != OK:
        http.queue_free()
        return {"ok": false, "error": "Connexion impossible : " + error_string(err)}
    var response: Array = await http.request_completed
    http.queue_free()
    if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
        return _http_failure(int(response[1]), int(response[0]))
    var queued: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
    if not queued is Dictionary or not queued.get("event_id", null) is String:
        return {"ok": false, "error": "Reponse de file IA invalide."}
    var stream := _new_http()
    stream.timeout = 240.0
    stream.body_size_limit = 24000000
    add_child(stream)
    err = stream.request(url + "/" + str(queued["event_id"]), _headers(["Accept: text/event-stream"]))
    if err != OK:
        stream.queue_free()
        return {"ok": false, "error": "Lecture du resultat impossible."}
    response = await stream.request_completed
    stream.queue_free()
    if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
        return _http_failure(int(response[1]), int(response[0]))
    return decode_event_stream((response[3] as PackedByteArray).get_string_from_utf8())

func decode_event_stream(body: String) -> Dictionary:
    for block in body.replace("\r\n", "\n").split("\n\n"):
        var event: String = ""
        var payload: String = ""
        for line in block.split("\n"):
            if line.begins_with("event: "):
                event = line.substr(7).strip_edges()
            elif line.begins_with("data: "):
                payload += line.substr(6)
        if event == "error":
            if payload.to_lower().contains("quota") or payload.to_lower().contains("runs limit"):
                return {"ok": false, "error_kind": "quota", "quota_detail": payload.substr(0, 600), "error": "Quota GPU gratuit atteint. Les dessins termines sont conserves ; aucun nouvel essai automatique sur ce moteur dans ce lot."}
            return {"ok": false, "error_kind": "hidden_server_error" if payload == "null" else "server_error", "error": "Le service IA a refuse ou interrompu le calcul. Les dessins termines sont conserves."}
        if event == "complete":
            var value: Variant = JSON.parse_string(payload)
            if value is Array:
                return {"ok": true, "data": value}
    return {"ok": false, "error": "Resultat IA absent. Aucune image inventee en remplacement."}

func _style_instruction(style: String) -> String:
    if STYLES.has(style):
        return str(STYLES[style][1])
    return "Requested visual style: " + style.strip_edges().substr(0, 160) + ". Preserve subject identity, appearance, proportions and visual consistency across frames."

func create_reference(description: String, style: String) -> Dictionary:
    if description.strip_edges().is_empty() or style.strip_edges().is_empty():
        return {"ok": false, "error": "Description ou style manquant."}
    var prompt: String = build_reference_prompt(description, style)
    var result: Dictionary = await _call_api(TEXT_URL, "generate_image", [prompt, 1024, 1024, 9, 1234, false])
    if not result.get("ok", false):
        return result
    var data: Array = result.get("data", [])
    if data.is_empty() or not data[0] is Dictionary:
        return {"ok": false, "error": "Fichier de reference absent."}
    var url: String = str(data[0].get("url", ""))
    if not url.begins_with(TEXT_URL + "/"):
        return {"ok": false, "error": "Adresse du dessin IA non reconnue."}
    var download := _new_http()
    download.timeout = 60.0
    download.body_size_limit = 12000000
    add_child(download)
    var err: Error = download.request(url, _headers([]))
    if err != OK:
        download.queue_free()
        return {"ok": false, "error": "Telechargement impossible."}
    var response: Array = await download.request_completed
    download.queue_free()
    if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
        return {"ok": false, "error": "Telechargement IA echoue."}
    var image := Image.new()
    var raw: PackedByteArray = response[3]
    if image.load_png_from_buffer(raw) != OK:
        if image.load_jpg_from_buffer(raw) != OK or image.is_empty():
            return {"ok": false, "error": "Dessin IA illisible."}
    return {"ok": true, "image": image, "model": "Z-Image-Turbo", "identity_verified": false}

func redraw(reference: Image, story: String, style: String, previous: Image = null, new_variation: bool = false) -> Dictionary:
    if reference == null or reference.is_empty() or style.strip_edges().is_empty() or story.strip_edges().is_empty():
        return {"ok": false, "error": "Image, directive ou style invalide."}
    var failures: Array[String] = []
    # A configured name or a reachable page is never proof of GPU availability.
    # Each provider is attempted at most once after a failure in this worker.
    for engine in ["qwen", "anypose"]:
        if engine_status.get(engine, {}).get("status", "") == "unavailable":
            failures.append(engine + ": " + str(engine_status[engine].get("error", "indisponible")))
            continue
        var result: Dictionary
        if engine == "qwen":
            result = await _redraw_qwen(reference, story, style, previous, new_variation)
        else:
            result = await _redraw_anypose(reference, story, style, previous, new_variation)
        if result.get("ok", false):
            var output: Image = result.get("image")
            if output != null and not output.is_empty():
                engine_status[engine] = {"status": "generated_unreviewed", "quota_remaining": "not_exposed", "identity_verified": false}
                result["engine"] = engine
                return result
            result = {"ok": false, "error": "Dessin absent ou illisible.", "error_kind": "invalid_image"}
        if result.get("error_kind", "") == "safety":
            return result
        engine_status[engine] = {"status": "unavailable", "error": result.get("error", "Erreur IA"), "error_kind": result.get("error_kind", "unknown"), "quota_detail": result.get("quota_detail", "")}
        failures.append(engine + ": " + str(result.get("error", "Erreur IA")))
    return {"ok": false, "error": "Aucun moteur n'a produit ce dessin. " + " | ".join(failures), "engines": engine_status.duplicate(true)}

func _redraw_qwen(reference: Image, story: String, style: String, previous: Image, new_variation: bool) -> Dictionary:
    var payload: Dictionary = build_edit_payload(reference, story, style, previous)
    var instruction: String = payload["instruction"]
    var safety: Dictionary = await _call_api(EDIT_URL, "check_safety", [instruction])
    if not safety.get("ok", false):
        return safety
    var check: Array = safety.get("data", [])
    if check.is_empty() or not check[0] is Dictionary or str(check[0].get("status", "")) != "ok":
        return {"ok": false, "error_kind": "safety", "error": "Directive refusee par le service d images."}
    var result: Dictionary = await _call_api(EDIT_URL, "edit_image", [JSON.stringify(payload["images"]), instruction, payload["adapter"], 1234, new_variation, 1.0, 4])
    if not result.get("ok", false):
        return result
    var data: Array = result.get("data", [])
    if data.is_empty() or not data[0] is Dictionary or str(data[0].get("status", "")) != "success":
        if not data.is_empty() and data[0] is Dictionary and str(data[0].get("status", "")) == "blocked":
            return {"ok": false, "error_kind": "safety", "error": "Directive refusee par le moteur d images."}
        return {"ok": false, "error": "Le moteur n a pas retourne de dessin."}
    var encoded: String = str(data[0].get("image", ""))
    if encoded.contains(","):
        encoded = encoded.get_slice(",", 1)
    if encoded.length() > 20000000:
        return {"ok": false, "error": "Dessin trop volumineux."}
    var output := Image.new()
    if output.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK or output.is_empty():
        return {"ok": false, "error": "PNG du moteur invalide."}
    return {"ok": true, "image": output, "model": "Qwen-Image-Edit-2511-Rapid", "identity_verified": false}

func _upload_anypose(images: Array[Image]) -> Dictionary:
    var boundary: String = "KarmaV54" + str(Time.get_ticks_usec())
    var body := PackedByteArray()
    for index in range(images.size()):
        body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"files\"; filename=\"reference_%d.png\"\r\nContent-Type: image/png\r\n\r\n" % [boundary, index]).to_utf8_buffer())
        body.append_array(images[index].save_png_to_buffer())
        body.append_array("\r\n".to_utf8_buffer())
    body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())
    var http := _new_http()
    http.timeout = 60.0
    http.body_size_limit = 1000000
    add_child(http)
    var err: Error = http.request_raw(ANYPOSE_URL + "/gradio_api/upload", _headers(["Content-Type: multipart/form-data; boundary=" + boundary]), HTTPClient.METHOD_POST, body)
    if err != OK:
        http.queue_free()
        return {"ok": false, "error": "Upload AnyPose impossible."}
    var response: Array = await http.request_completed
    http.queue_free()
    if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
        return _http_failure(int(response[1]), int(response[0]))
    var paths: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
    if not paths is Array or paths.size() != images.size():
        return {"ok": false, "error": "Reponse upload AnyPose incompatible."}
    var files: Array = []
    for path in paths:
        if not path is String or path.is_empty():
            return {"ok": false, "error": "Fichier AnyPose manquant."}
        files.append({"path": path, "meta": {"_type": "gradio.FileData"}})
    return {"ok": true, "files": files}

func _redraw_anypose(reference: Image, story: String, style: String, previous: Image, new_variation: bool) -> Dictionary:
    if detailed_layout(style):
        return {"ok": false, "error_kind": "unsupported_style_guide", "error": "AnyPose ne prend pas en charge ce parcours avec reference de style. Aucun dessin simplifie n'est substitue."}
    var images: Array[Image] = [reference]
    if previous != null:
        images.append(previous)
    var uploaded: Dictionary = await _upload_anypose(images)
    if not uploaded.get("ok", false):
        return uploaded
    var files: Array = uploaded["files"]
    var instruction: String = _style_instruction(style) + " Image 1 is the permanent subject reference. " + story
    if previous != null:
        instruction += " Image 2 is previous temporal context, not an extra subject. Render only the requested new states."
    var result: Dictionary = await _call_api(ANYPOSE_URL, "infer", [files[0], files[1] if files.size() > 1 else files[0], instruction, 1234, new_variation, 1.0, 4, 1024, 1024, false])
    if not result.get("ok", false):
        return result
    var data: Array = result.get("data", [])
    if data.is_empty() or not data[0] is Array or data[0].is_empty() or not data[0][0] is Dictionary:
        return {"ok": false, "error": "Galerie AnyPose incompatible."}
    var file: Variant = data[0][0].get("image", {})
    if not file is Dictionary:
        return {"ok": false, "error": "Image AnyPose absente."}
    var url: String = str(file.get("url", ""))
    if not url.begins_with(ANYPOSE_URL + "/gradio_api/file="):
        return {"ok": false, "error": "Adresse de sortie AnyPose non reconnue."}
    var http := _new_http()
    http.timeout = 60.0
    http.body_size_limit = 12000000
    add_child(http)
    if http.request(url, _headers([])) != OK:
        http.queue_free()
        return {"ok": false, "error": "Telechargement AnyPose impossible."}
    var response: Array = await http.request_completed
    http.queue_free()
    if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
        return _http_failure(int(response[1]), int(response[0]))
    var output := Image.new()
    var bytes: PackedByteArray = response[3]
    if output.load_png_from_buffer(bytes) != OK and output.load_webp_from_buffer(bytes) != OK and output.load_jpg_from_buffer(bytes) != OK:
        return {"ok": false, "error": "Dessin AnyPose illisible."}
    if output.is_empty():
        return {"ok": false, "error": "Dessin AnyPose vide."}
    return {"ok": true, "image": output, "model": "Qwen-Image-Edit-2511-AnyPose", "identity_verified": false}

func batch_prompt(briefs: Array, rows: int = 2) -> String:
    var layout: String = "a 2 by 2 animation storyboard grid of FOUR equal square panels, read left to right then top to bottom" if rows == 2 else "exactly TWO equal portrait animation panels side by side, read left to right, one row and two columns"
    var prompt: String = "Create " + layout + ". Reproduce ALL subjects, characters, animals, vehicles, objects and environmental elements actually present in image 1, preserving their identities, count, appearance, spatial relationships and stable background across every panel unless the requested action explicitly changes them. Do not merge subjects, invent extra actors, humanize non-human objects or remove scenery. Keep moving subjects and relevant interacting objects fully visible with comfortable margins. Preserve silhouettes, faces if present, existing appendages, markings, materials, proportions, colors, drawing style, lighting and ground contact. Render the requested action as visibly different successive physical states, not merely alternate camera angles. "
    for index in range(briefs.size()):
        var position: String = ""
        if briefs[index].has("sequence_index") and briefs[index].has("sequence_count"):
            position = "Sequence drawing %d of %d; continue the action at this exact stage without restarting it. " % [int(briefs[index]["sequence_index"]) + 1, int(briefs[index]["sequence_count"])]
        prompt += "Panel %d: %s%s; %s. " % [index + 1, position, str(briefs[index].get("description", "")), str(briefs[index].get("pose", ""))]
    if briefs.size() < rows * 2:
        prompt += "Leave the remaining panels empty. "
    return prompt + "Equal panel sizes, no gutters, no captions, no text, no unrequested characters or objects, no human torso unless already present or explicitly requested. Every used panel must advance the requested action with a different physically plausible state of the relevant subjects and interacting objects. Keep unaffected subjects and environmental landmarks stable; do not substitute camera changes or image deformation for motion. Lock the camera position, focal length, horizon, subject scale and panel framing across this sequence unless a camera change is explicitly requested. Keep the complete moving subject inside each panel, including head and existing extremities. Preserve the exact clothing cut, seams, footwear, accessories, face and hair details actually present; do not invent markings, ground debris, motion trails or new props. For articulated subjects use only their existing limbs, with consistent joints and ground contact."

func split_batch(sheet: Image, count: int, rows: int = 2) -> Dictionary:
    if sheet == null or sheet.is_empty() or rows not in [1, 2] or count < 2 or count > rows * 2 or sheet.get_width() < 1024 or sheet.get_height() < 1024:
        return {"ok": false, "error": "Planche IA insuffisante pour des dessins de 512 pixels minimum."}
    var frames: Array[Image] = []
    for index in range(count):
        var col: int = index % 2
        var row: int = index / 2
        var x1: int = col * sheet.get_width() / 2
        var y1: int = row * sheet.get_height() / rows
        var x2: int = (col + 1) * sheet.get_width() / 2
        var y2: int = (row + 1) * sheet.get_height() / rows
        frames.append(sheet.get_region(Rect2i(x1, y1, x2 - x1, y2 - y1)))
    return {"ok": true, "images": frames, "layout_verified": false, "identity_verified": false}

func redraw_batch(reference: Image, briefs: Array, style: String, previous: Image = null) -> Dictionary:
    if reference == null or reference.is_empty() or briefs.is_empty() or briefs.size() > max_batch_size(style):
        return {"ok": false, "error": "Lot de dessins invalide."}
    if briefs.size() == 1:
        var single: Dictionary = await redraw(reference, str(briefs[0]["instruction"]), style, previous)
        if single.get("ok", false):
            single["images"] = [single["image"]]
        return single
    # Square conditioning canvas preserves proportions and never overwrites the
    # original. It makes the fixed 1024px service produce 512px square cells.
    var source: Image = reference.duplicate()
    var scale_factor: float = 1024.0 / float(maxi(source.get_width(), source.get_height()))
    source.resize(maxi(1, roundi(source.get_width() * scale_factor)), maxi(1, roundi(source.get_height() * scale_factor)), Image.INTERPOLATE_LANCZOS)
    var canvas := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
    canvas.fill(reference.get_pixel(0, 0))
    source.convert(Image.FORMAT_RGBA8)
    canvas.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i((1024 - source.get_width()) / 2, (1024 - source.get_height()) / 2))
    var rows: int = 1 if detailed_layout(style) else 2
    var result: Dictionary = await redraw(canvas, batch_prompt(briefs, rows), style, previous)
    if not result.get("ok", false):
        return result
    var split: Dictionary = split_batch(result["image"], briefs.size(), rows)
    if split.get("ok", false):
        split["sheet"] = result["image"]
        split["model"] = result.get("model", "")
        split["engine"] = result.get("engine", "")
    return split


func _new_http() -> HTTPRequest:
    var http := HTTPRequest.new()
    # Optional managed-development proxy; ordinary Android uses direct HTTPS.
    var proxy: String = OS.get_environment("HTTPS_PROXY")
    if proxy.begins_with("http://") and not proxy.contains("@"):
        var parts: PackedStringArray = proxy.trim_prefix("http://").trim_suffix("/").rsplit(":", true, 1)
        if parts.size() == 2 and parts[1].is_valid_int():
            http.set_https_proxy(parts[0], int(parts[1]))
    return http


func _headers(values: Array) -> PackedStringArray:
    var headers := PackedStringArray(values)
    if not hf_token.strip_edges().is_empty():
        headers.append("Authorization: Bearer " + hf_token.strip_edges())
    return headers


func build_reference_prompt(description: String, style: String) -> String:
    if style.strip_edges().is_empty():
        return ""
    var style_text: String = _style_instruction(style)
    if style == "original":
        style_text = "Faithfully depict the subject described by the user."
    # Subject type belongs to the user. A fruit/object must not become a human
    # wearing that object, unless the user explicitly requests that transformation.
    return "User subject description (preserve its meaning exactly): " + description.strip_edges() + ". " + style_text + " Create one image of that subject itself, do not replace it with a person holding, wearing, or displaying it unless explicitly requested. Do not invent a human body or human features unless requested in the description. Show the whole subject within the frame. No text, no watermark, no panels."
