extends Node
# Image-to-image sequence adapter for a user-supplied HTTPS generation service.
# Protocol: POST {image_base64, prompt, frame_index, total_frames, previous_image_base64, loop}
# Response: {image_base64: "<PNG base64>"}; no paid API or endpoint is bundled.
signal progress(index: int, total: int)
var cancel_requested := false

func generate(source: Image, prompt: String, endpoint: String, count: int = 12, loop: bool = false) -> Dictionary:
 if source == null or source.is_empty():
  return {"ok": false, "error": "Image source absente"}
 if prompt.strip_edges().is_empty():
  return {"ok": false, "error": "Consigne absente"}
 if not endpoint.begins_with("https://"):
  return {"ok": false, "error": "Adresse HTTPS du moteur image-to-image requise"}
 if count < 2 or count > 120:
  return {"ok": false, "error": "Nombre d'images hors limites (2-120)"}
 cancel_requested = false
 var reference := source.duplicate()
 var limit := 1024.0
 if reference.get_width() > 1024 or reference.get_height() > 1024:
  var ratio: float = minf(limit / float(reference.get_width()), limit / float(reference.get_height()))
  reference.resize(maxi(1, roundi(reference.get_width() * ratio)), maxi(1, roundi(reference.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
 var source_png: PackedByteArray = reference.save_png_to_buffer()
 if source_png.is_empty():
  return {"ok": false, "error": "Impossible d'encoder l'image source"}
 var reference_b64: String = Marshalls.raw_to_base64(source_png)
 var previous_b64: String = reference_b64
 var frames: Array[Image] = []
 for index in range(count):
  if cancel_requested:
   return {"ok": false, "error": "Generation annulee", "generated": frames.size()}
  var http := HTTPRequest.new()
  http.timeout = 120.0
  add_child(http)
  var payload := {
   "image_base64": reference_b64,
   "previous_image_base64": previous_b64,
   "prompt": prompt,
   "frame_index": index,
   "total_frames": count,
   "loop": loop,
   "reference_strength": 0.85,
   "temporal_position": float(index) / float(count)
  }
  var err := http.request(endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
  if err != OK:
   http.queue_free()
   return {"ok": false, "error": "Requete impossible : %s" % error_string(err), "generated": frames.size()}
  var response: Array = await http.request_completed
  http.queue_free()
  if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
   return {"ok": false, "error": "Erreur moteur : %s / HTTP %s" % [response[0], response[1]], "generated": frames.size()}
  var data: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
  if not data is Dictionary or not data.has("image_base64"):
   return {"ok": false, "error": "Reponse invalide : image_base64 manquant", "generated": frames.size()}
  var raw: PackedByteArray = Marshalls.base64_to_raw(str(data["image_base64"]))
  var img := Image.new()
  if img.load_png_from_buffer(raw) != OK or img.is_empty():
   return {"ok": false, "error": "PNG invalide", "generated": frames.size()}
  if img.get_width() > 1024 or img.get_height() > 1024:
   return {"ok": false, "error": "Image trop grande", "generated": frames.size()}
  frames.append(img)
  previous_b64 = str(data["image_base64"])
  progress.emit(index + 1, count)
 return {"ok": true, "frames": frames, "count": frames.size()}

func cancel() -> void:
 cancel_requested = true
