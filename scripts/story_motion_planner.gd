extends RefCounted
# Offline, deterministic movement storyboard planner. No image AI or network.
const KEYWORDS: Dictionary = {
    "transformation": ["se transforme", "transforme", "devient", "transformation", "dragon", "transform into", "turns into"],
    "metro": ["metro", "métro", "subway", "underground train"],
    "football": ["football", "foot", "soccer", "joue au ballon"],
    "course": ["courir", "court", "course", "sprint", "run", "running"],
    "chute": ["tombe", "tomber", "chute", "fall", "falling"],
    "trebuche": ["trebuche", "trébuche", "trip", "stumble"],
    "marche": ["marche", "marcher", "walk", "walking"],
    "danse": ["danse", "danser", "dance", "dancing"],
    "salut": ["salue", "saluer", "salut", "wave"],
    "saut": ["saute", "sauter", "jump"],
    "releve": ["releve", "relève", "relever", "gets up", "stand up"],
    "repos": ["arrete", "arrête", "stop", "immobile", "attend"]
}
const TRANSITIONS: Array[String] = ["et puis", "et apres", "et ensuite", "tout a coup", "d'un coup", "puis", "ensuite", "apres", "soudain", "then", "suddenly"]

func _normalize(value: String) -> String:
    var result: String = value.to_lower().strip_edges()
    var src: String = "àâäéèêëîïôöùûüç"
    var dst: String = "aaaeeeeiioouuuc"
    for i in range(src.length()):
        result = result.replace(src.substr(i, 1), dst.substr(i, 1))
    return result

func _action_for(fragment: String) -> String:
    # Explicit priorities avoid "tombe" being treated as an unrelated movement.
    for action in ["transformation", "metro", "football", "trebuche", "chute", "releve", "saut", "course", "marche", "danse", "salut", "repos"]:
        for keyword in KEYWORDS[action]:
            if fragment.contains(_normalize(keyword)):
                return action
    return "inconnu"

func plan(story: String, seconds: float = 6.0) -> Dictionary:
    var normalized: String = _normalize(story)
    for mark in [".", ";", ",", "!", "?", "\n"]:
        normalized = normalized.replace(mark, "|")
    for transition in TRANSITIONS:
        normalized = normalized.replace(" " + transition + " ", "|")
    var recognized: Array[Dictionary] = []
    for part in normalized.split("|", false):
        var phrase: String = part.strip_edges()
        var action: String = _action_for(phrase)
        if action != "inconnu":
            recognized.append({"action": action, "description": phrase})
    if recognized.is_empty():
        return {"ok": false, "error": "Aucun mouvement reconnu", "steps": []}
    var total: float = maxf(0.5, seconds)
    var weights: Array[float] = []
    var sum_weights: float = 0.0
    for step in recognized:
        var w: float = 0.65 if step["action"] == "chute" or step["action"] == "trebuche" else 1.0
        weights.append(w)
        sum_weights += w
    var cursor: float = 0.0
    var steps: Array[Dictionary] = []
    for i in range(recognized.size()):
        var end: float = total if i == recognized.size() - 1 else cursor + total * weights[i] / sum_weights
        steps.append({"action": recognized[i]["action"], "description": recognized[i]["description"], "start": cursor, "end": end})
        cursor = end
    return {"ok": true, "duration": total, "steps": steps}

func action_at(data: Dictionary, seconds: float) -> String:
    var steps: Array = data.get("steps", [])
    for step in steps:
        if seconds < float(step["end"]):
            return str(step["action"])
    return str(steps[-1]["action"]) if not steps.is_empty() else "repos"
