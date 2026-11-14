extends Node
# Image-to-image sequence adapter for a user-supplied HTTPS generation service.
# Protocol: POST {image_base64, prompt, frame_index, total_frames, previous_image_base64, loop}
# Response: {image_base64: "<PNG base64>"}; no paid API or endpoint is bundled.
signal progress(index: int, total: int)
var cancel_requested := false

func generate(source: Image, prompt: String, endpoint: String, count: int = 12, loop: bool = false, api_token: String = "") -> Dictionary:
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
 var motion_plan: Dictionary = load("res://scripts/story_motion_planner.gd").new().plan(prompt, float(count))
 var motion_steps: Array = motion_plan.get("steps", [])
 # Do not silently draw a generic dancing/standing figure for an action
 # that the offline pose catalog cannot represent. Ask for a supported
 # movement instead of returning misleading generated frames.
 for step in motion_steps:
  if bool(step.get("needs_generation", false)):
   return {"ok": false, "error": "Mouvement sans guide de pose : %s. Aucun dessin trompeur ne sera genere." % str(step.get("description", ""))}
 for index in range(count):
  if cancel_requested:
   return {"ok": false, "error": "Generation annulee", "generated": frames.size()}
  var http := HTTPRequest.new()
  http.timeout = 120.0
  add_child(http)
  # Select the description from the same timed step as the pose.
  # Equal-sized indexing breaks when actions have different durations.
  var active_prompt: String = prompt
  var seconds: float = float(index) / float(maxi(1, count - 1)) * float(count)
  for step in motion_steps:
   if seconds < float(step.get("end", 0.0)) or step == motion_steps.back():
    active_prompt = str(step.get("description", prompt))
    break
  # A pose-conditioned model needs an actual pose image, not just a
  # text instruction. Keep the identity reference unchanged across frames.
  var action: String = "danse"
  if bool(motion_plan.get("ok", false)):
   action = load("res://scripts/story_motion_planner.gd").new().action_at(motion_plan, float(index) / float(maxi(1, count - 1)) * float(count))
  # Normalize movement progress INSIDE each story action. Absolute frame
  # indices caused falls to snap instantly and later steps to inherit
  # unrelated phases.
  var local_phase: float = 0.0
  var steps: Array = motion_plan.get("steps", [])
  for step in steps:
   if seconds < float(step.get("end", 0.0)) or step == steps.back():
    var start_time: float = float(step.get("start", 0.0))
    var end_time: float = float(step.get("end", start_time + 1.0))
    local_phase = clampf((seconds - start_time) / maxf(0.001, end_time - start_time), 0.0, 1.0)
    break
  # Cyclic actions need repeated steps; single-event actions need
  # monotonic 0..1 progress. Otherwise running appears to freeze.
  var render_phase: float = local_phase
  if action == "course" or action == "marche" or action == "danse":
   render_phase = seconds * (1.8 if action == "course" else 1.0)
  var guide_generator: RefCounted = load("res://scripts/procedural_cartoon_generator.gd").new()
  var guide: Image = guide_generator.render(prompt, render_phase, Vector2i(360, 480), action)
  if guide == null or guide.is_empty():
   http.queue_free()
   return {"ok": false, "error": "Guide de pose impossible a generer", "generated": frames.size()}
  var pose_png: PackedByteArray = guide.save_png_to_buffer()
  if pose_png.is_empty():
   http.queue_free()
   return {"ok": false, "error": "Encodage du guide de pose impossible", "generated": frames.size()}
  var payload := {
   "pose_image_base64": Marshalls.raw_to_base64(pose_png),
   "pose_action": action,
   "image_base64": reference_b64,
   "previous_image_base64": previous_b64,
   "prompt": active_prompt,
   "full_story": prompt,
   "frame_index": index,
   "total_frames": count,
   "loop": loop,
   "reference_strength": 0.85,
   "temporal_position": float(index) / float(maxi(1, count - 1))
  }
  var headers := PackedStringArray(["Content-Type: application/json"])
  if not api_token.is_empty():
   headers.append("Authorization: Bearer " + api_token)
  var err := http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
  if err != OK:
   http.queue_free()
   return {"ok": false, "error": "Requete impossible : %s" % error_string(err), "generated": frames.size()}
  var response: Array = await http.request_completed
  http.queue_free()
  if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
   var http_code: int = int(response[1])
   var retryable: bool = http_code == 429 or http_code == 503 or http_code == 502 or http_code == 504
   return {"ok": false, "error": "Moteur indisponible (HTTP %s). %s" % [http_code, "Reessayer ou choisir un autre moteur HTTPS." if retryable else "Verifier la configuration du moteur."], "generated": frames.size(), "retryable": retryable, "http_status": http_code}
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
