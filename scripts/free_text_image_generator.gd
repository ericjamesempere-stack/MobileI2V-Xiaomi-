extends Node
# Experimental no-key text-to-image adapter. Does not upload the user's photo,
# and cannot guarantee identity preservation or pose conditioning.
signal progress(index: int, total: int)
var cancel_requested := false
const HOST := "https://image.pollinations.ai/prompt/"
const MAX_IMAGES := 4

func generate(story: String, visual_style: String, count: int = 2) -> Dictionary:
 if story.strip_edges().is_empty():
  return {"ok": false, "error": "Histoire absente"}
 if count < 1 or count > MAX_IMAGES:
  return {"ok": false, "error": "Mode gratuit limite a quatre images par essai"}
 cancel_requested = false
 var frames: Array[Image] = []
 var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
 var story_plan: Dictionary = planner.plan(story, float(count))
 if not bool(story_plan.get("ok", false)):
  return {"ok": false, "error": str(story_plan.get("error", "Histoire invalide"))}
 var story_steps: Array = story_plan.get("steps", [])
 for i in range(count):
  if cancel_requested:
   return {"ok": false, "error": "Annule", "generated": frames.size()}
  # The provider only accepts text, not pose_image_base64 or image references.
  var seconds: float = (float(i) + 0.5) * float(story_plan.get("duration", float(count))) / float(count)
  var scene_description: String = story
  for story_step in story_steps:
   if seconds < float(story_step.get("end", 0.0)) or story_step == story_steps.back():
    scene_description = str(story_step.get("description", story))
    break
  var scene_prompt := "Original animated film storyboard. Character performs: %s. Overall story: %s. %s style, consistent character costume, full body, animation storyboard keyframe %d of %d" % [scene_description, story, visual_style, i + 1, count]
  var url := HOST + scene_prompt.uri_encode() + "?width=512&height=768&seed=" + str(4242 + i)
  var http := HTTPRequest.new()
  http.timeout = 120.0
  http.body_size_limit = 6000000
  add_child(http)
  var err := http.request(url)
  if err != OK:
   http.queue_free()
   return {"ok": false, "error": "Connexion impossible : " + error_string(err), "generated": frames.size()}
  var response: Array = await http.request_completed
  http.queue_free()
  if cancel_requested:
   return {"ok": false, "error": "Annule", "generated": frames.size()}
  var code: int = int(response[1])
  if int(response[0]) != HTTPRequest.RESULT_SUCCESS or code != 200:
   return {"ok": false, "error": "Service gratuit indisponible ou quota atteint (HTTP %d)" % code, "generated": frames.size(), "http_status": code}
  var bytes: PackedByteArray = response[3] as PackedByteArray
  var img := Image.new()
  if img.load_jpg_from_buffer(bytes) != OK:
   if img.load_png_from_buffer(bytes) != OK:
    return {"ok": false, "error": "Le fournisseur n'a pas retourne une image valide", "generated": frames.size()}
  if img.is_empty() or img.get_width() < 64 or img.get_height() < 64:
   return {"ok": false, "error": "Image recue inutilisable", "generated": frames.size()}
  frames.append(img)
  progress.emit(i + 1, count)
  if i + 1 < count:
   # Anonymous free endpoints commonly throttle unique prompts.
   await get_tree().create_timer(46.0).timeout
 return {"ok": true, "frames": frames, "method": "pollinations_text_to_image", "identity_verified": false, "pose_conditioned": false}

func cancel() -> void:
 cancel_requested = true
