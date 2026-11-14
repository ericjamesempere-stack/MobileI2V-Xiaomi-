extends RefCounted
# Planificateur deterministe hors ligne. Ne pretend pas generer de nouvelles poses.
const VOCAB := {
 "marche": ["marche", "marcher", "walk", "walking", "avance"],
 "course": ["cours", "court", "courir", "course", "running", "run", "accelere"],
 "chute": ["tombe", "tomber", "chute", "trebuche", "fall", "trip"],
 "salut": ["salut", "salue", "wave", "waving"],
 "danse": ["danse", "danser", "dance", "groove"]
}
const ORDER := ["marche", "course", "chute", "salut", "danse"]

static func plan(prompt: String, seconds_per_action: float = 5.0) -> Array[Dictionary]:
 var normalized := prompt.to_lower().strip_edges()
 var matches: Array[Dictionary] = []
 for action in ORDER:
  for keyword in VOCAB[action]:
   var offset := normalized.find(keyword)
   if offset >= 0:
    matches.append({"action": action, "position": offset})
    break
 matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["position"]) < int(b["position"]))
 var result: Array[Dictionary] = []
 var cursor := 0.0
 for item in matches:
  var name: String = item["action"]
  var duration := maxf(0.5, seconds_per_action)
  result.append({"action": name, "start": cursor, "duration": duration, "supported": name in ["marche", "salut", "danse"]})
  cursor += duration
 return result
