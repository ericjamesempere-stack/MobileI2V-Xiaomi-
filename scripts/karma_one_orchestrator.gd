extends Node
# KARMA ONE: deterministic orchestration of configured HTTPS image generators.
# No fictitious provider, quota bypass, or unverified "AI" fallback.
signal progress(index: int, total: int)
var cancel_requested: bool = false

func generate(source: Image, prompt: String, endpoints: String, count: int = 12, loop: bool = false, token: String = "", duration: float = 0.0) -> Dictionary:
 cancel_requested = false
 var providers: Array[String] = []
 for candidate in endpoints.replace("\n", ";").split(";"):
  var address: String = candidate.strip_edges()
  if address.begins_with("https://") and not providers.has(address):
   providers.append(address)
 if providers.is_empty():
  return {"ok": false, "error": "KARMA ONE : aucun moteur HTTPS configure"}
 var errors: Array[String] = []
 for address in providers:
  if cancel_requested:
   return {"ok": false, "error": "Generation annulee"}
  var worker := Node.new()
  worker.set_script(load("res://scripts/image_sequence_generator.gd"))
  add_child(worker)
  worker.progress.connect(func(index: int, total: int) -> void:
   progress.emit(index, total)
  )
  var result: Dictionary = await worker.call("generate", source, prompt, address, count, loop, token, duration)
  worker.queue_free()
  if bool(result.get("ok", false)):
   result["provider"] = address
   return result
  errors.append("%s : %s" % [address, str(result.get("error", "erreur inconnue"))])
  # Authentication, invalid requests and unsupported actions are not
  # solved by switching providers; stop instead of burning quotas.
  var status: int = int(result.get("http_status", 0))
  if status == 400 or status == 401 or status == 403 or status == 422:
   break
  if str(result.get("error", "")).contains("Mouvement sans guide"):
   break
 return {"ok": false, "error": "KARMA ONE : " + " | ".join(errors)}
func cancel() -> void:
 cancel_requested = true
