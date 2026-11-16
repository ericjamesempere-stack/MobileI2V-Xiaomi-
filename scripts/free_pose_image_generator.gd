extends Node
# Experimental Gradio ZeroGPU ControlNet. Uses pose guides, not identity image conditioning.
# No paid API. Public service may reject requests, queue indefinitely, or change its API.
signal progress(index: int, total: int)
var cancel_requested := false
const HOST := "https://techfreakworm-z-image-studio.hf.space"
const LIMIT := 2

func _fetch(url: String, method: int = HTTPClient.METHOD_GET, body: String = "", headers: PackedStringArray = PackedStringArray()) -> Dictionary:
 var req := HTTPRequest.new()
 req.timeout = 180.0
 req.body_size_limit = 8000000
 add_child(req)
 var err: Error = req.request(url, headers, method, body)
 if err != OK:
  req.queue_free()
  return {"ok": false, "error": error_string(err)}
 var response: Array = await req.request_completed
 req.queue_free()
 if cancel_requested:
  return {"ok": false, "error": "Annule"}
 if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
  return {"ok": false, "error": "HTTP %d" % int(response[1])}
 return {"ok": true, "text": (response[3] as PackedByteArray).get_string_from_utf8(), "bytes": response[3]}

func generate(story: String, visual_style: String, count: int = 2) -> Dictionary:
 if count < 1 or count > LIMIT:
  return {"ok": false, "error": "Essai ControlNet limite a deux images"}
 if story.strip_edges().is_empty():
  return {"ok": false, "error": "Histoire vide"}
 cancel_requested = false
 var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
 var guide_generator: RefCounted = load("res://scripts/openpose_guide_generator.gd").new()
 var plan: Dictionary = planner.plan(story, float(count))
 if not bool(plan.get("ok", false)):
  return {"ok": false, "error": str(plan.get("error", "Plan invalide"))}
 var frames: Array[Image] = []
 for i in range(count):
  if cancel_requested:
   return {"ok": false, "error": "Annule", "generated": frames.size()}
  var seconds := (float(i) + 0.5) / float(count) * float(plan.get("duration", count))
  var action: String = str(planner.action_at(plan, seconds))
  var phase := float(i) / float(maxi(1, count - 1))
  var pose: Image = guide_generator.render(story, phase, Vector2i(384, 384), action)
  var pose_b64: String = Marshalls.raw_to_base64(pose.save_png_to_buffer())
  var prompt := "One single original 2D %s cartoon character, full body, consistent appearance, clean white background, pose: %s. Story: %s" % [visual_style, action, story]
  var args := [prompt, {"url": "data:image/png;base64," + pose_b64, "meta": {"_type": "gradio.FileData"}, "orig_name": "pose.png"}, "Pre-processed", 1.2, 8, 20261116, false, null, 0.0]
  var started: Dictionary = await _fetch(HOST + "/gradio_api/call/on_controlnet_generate", HTTPClient.METHOD_POST, JSON.stringify({"data": args}), PackedStringArray(["Content-Type: application/json"]))
  if not bool(started.get("ok", false)):
   return {"ok": false, "error": "Demarrage ControlNet : " + str(started.get("error", "")), "generated": frames.size()}
  var ticket: Variant = JSON.parse_string(str(started.get("text", "")))
  if not ticket is Dictionary or not ticket.has("event_id"):
   return {"ok": false, "error": "Ticket ControlNet absent", "generated": frames.size()}
  var event_id: String = str(ticket["event_id"])
  if event_id.length() < 8 or event_id.contains("/") or event_id.contains("?"):
   return {"ok": false, "error": "Ticket ControlNet invalide", "generated": frames.size()}
  var done: Dictionary = await _fetch(HOST + "/gradio_api/call/on_controlnet_generate/" + event_id)
  if not bool(done.get("ok", false)):
   return {"ok": false, "error": "Attente ControlNet : " + str(done.get("error", "")), "generated": frames.size()}
  var event := ""
  var image_url := ""
  for line in str(done.get("text", "")).split("\n"):
   if line.begins_with("event:"):
    event = line.substr(6).strip_edges()
   elif line.begins_with("data:") and event == "complete":
    var data: Variant = JSON.parse_string(line.substr(5).strip_edges())
    if data is Array and data.size() > 0 and data[0] is Dictionary:
     image_url = str(data[0].get("url", ""))
     break
  if not image_url.begins_with(HOST + "/gradio_api/file="):
   return {"ok": false, "error": "ControlNet indisponible ou fichier image absent", "generated": frames.size()}
  var fetched: Dictionary = await _fetch(image_url)
  if not bool(fetched.get("ok", false)):
   return {"ok": false, "error": "Telechargement dessin impossible", "generated": frames.size()}
  var img := Image.new()
  var bytes: PackedByteArray = fetched["bytes"]
  if img.load_webp_from_buffer(bytes) != OK or img.is_empty():
   return {"ok": false, "error": "Dessin WebP invalide", "generated": frames.size()}
  frames.append(img)
  progress.emit(i + 1, count)
 return {"ok": true, "frames": frames, "method": "zimage_controlnet_pose_experimental", "identity_verified": false, "pose_conditioned": true}

func cancel() -> void:
 cancel_requested = true
