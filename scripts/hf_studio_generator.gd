extends Node
# Real remote inference. Public services have quotas and can become unavailable.
signal progress(index: int, total: int)
const TEXT_URL = "https://mrfakename-z-image-turbo.hf.space"
const EDIT_URL = "https://prithivmlmods-qwen-image-edit-2511-loras-fast.hf.space"
const STYLES = {
    "original": ["Anything2Real", "Keep the exact original drawing style, subject type, appearance, proportions, materials and colors. Preserve only features actually present in the reference."],
    "cartoon": ["Anime-V2", "2D cartoon animation, clean expressive outlines, flat colors, consistent subject design."],
    "manga": ["Manga-Tone", "Japanese manga illustration, black and white ink, controlled screentones, consistent subject design."],
    "anime": ["Anime-V2", "Japanese anime animation, clean line art and cel shading, consistent subject design."],
    "3d": ["Pixar-Inspired-3D", "Stylized 3D rendered animation, coherent materials, soft studio lighting, consistent subject design."],
    "cinema": ["Anything2Real", "Cinematic realistic image, coherent lighting, physically plausible materials, consistent subject identity."]
}
var last_error: String = ""
var hf_token: String = ""

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
        return {"ok": false, "error": "Service IA indisponible (HTTP %d, reseau %d)." % [response[1], response[0]]}
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
        return {"ok": false, "error": "File GPU indisponible (HTTP %d)." % response[1]}
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
                return {"ok": false, "error": "Quota GPU gratuit atteint. Attends son renouvellement ou utilise ton compte Hugging Face gratuit via le champ de jeton dans Réglages et outils."}
            return {"ok": false, "error": "Le service IA a refuse ou interrompu le calcul. Les dessins termines sont conserves."}
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
    var instruction: String = _style_instruction(style) + " Image 1 is the permanent subject reference. " + story
    if previous != null:
        instruction += " Image 2 is temporal context only, not an additional subject or a target pose. Keep identity and background continuity, but render ONLY the new pose requested above."
    var safety: Dictionary = await _call_api(EDIT_URL, "check_safety", [instruction])
    if not safety.get("ok", false):
        return safety
    var check: Array = safety.get("data", [])
    if check.is_empty() or not check[0] is Dictionary or str(check[0].get("status", "")) != "ok":
        return {"ok": false, "error": "Directive refusee par le service d images."}
    var images: Array[String] = [Marshalls.raw_to_base64(reference.save_png_to_buffer())]
    if previous != null:
        images.append(Marshalls.raw_to_base64(previous.save_png_to_buffer()))
    var result: Dictionary = await _call_api(EDIT_URL, "edit_image", [JSON.stringify(images), instruction, str(STYLES[style][0]) if STYLES.has(style) else "Anything2Real", 1234, new_variation, 1.0, 4])
    if not result.get("ok", false):
        return result
    var data: Array = result.get("data", [])
    if data.is_empty() or not data[0] is Dictionary or str(data[0].get("status", "")) != "success":
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
