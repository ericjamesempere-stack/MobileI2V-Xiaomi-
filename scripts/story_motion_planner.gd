extends RefCounted
# KARMA ONE - Planificateur local d'actions. Aucune API ni connexion requise.
# Produit des etapes temporelles deterministes; ne genere pas d'images IA.
const ACTIONS: Dictionary = {
    "course": ["courir", "court", "course", "running", "run", "sprint"],
    "chute": ["tomber", "tombe", "chute", "fall", "falls", "falling"],
    "marche": ["marcher", "marche", "walking", "walk"],
    "danse": ["danser", "danse", "dancing", "dance"],
    "salut": ["saluer", "salue", "salut", "wave", "waving"],
    "saut": ["sauter", "saute", "jump", "jumping"],
    "repos": ["arrete", "arreter", "stop", "immobile", "attend", "wait"]
}
const TRANSITIONS: Array[String] = [
    "puis", "ensuite", "apres", "soudain", "brusquement",
    "d'un coup", "tout a coup", "et puis", "then", "suddenly", "after"
]

func _normalize(value: String) -> String:
    var text: String = value.to_lower().strip_edges()
    var source: String = "àâäéèêëîïôöùûüç"
    var target: String = "aaaeeeeiioouuuc"
    for i in range(source.length()):
        text = text.replace(source.substr(i, 1), target.substr(i, 1))
    return text

func _split_story(story: String) -> Array[String]:
    var text: String = _normalize(story)
    for separator in [".", ";", ",", "!", "?", "\n"]:
        text = text.replace(separator, "|")
    for transition in TRANSITIONS:
        text = text.replace(" " + transition + " ", "|")
    var parts: Array[String] = []
    for fragment in text.split("|", false):
        var cleaned: String = fragment.strip_edges()
        if not cleaned.is_empty():
            parts.append(cleaned)
    return parts

func _action_for(fragment: String) -> String:
    for action in ACTIONS.keys():
        for keyword in ACTIONS[action]:
            if fragment.find(str(keyword)) >= 0:
                return str(action)
    return "inconnu"

func plan(story: String, total_seconds: float = 5.0) -> Dictionary:
    var fragments: Array[String] = _split_story(story)
    if fragments.is_empty():
        return {"ok": false, "error": "Histoire vide", "steps": []}
    var recognized: Array[Dictionary] = []
    for fragment in fragments:
        var action: String = _action_for(fragment)
        if action != "inconnu":
            recognized.append({"action": action, "description": fragment})
    if recognized.is_empty():
        return {"ok": false, "error": "Aucun mouvement reconnu", "steps": []}
    var duration: float = maxf(total_seconds, 0.5)
    var weights: Array[float] = []
    var total_weight: float = 0.0
    for step in recognized:
        var weight: float = 0.65 if step["action"] == "chute" else 1.0
        weights.append(weight)
        total_weight += weight
    var steps: Array[Dictionary] = []
    var cursor: float = 0.0
    for i in range(recognized.size()):
        var seconds: float = duration * weights[i] / total_weight
        var finish: float = duration if i == recognized.size() - 1 else cursor + seconds
        steps.append({
            "index": i,
            "action": recognized[i]["action"],
            "description": recognized[i]["description"],
            "start": cursor,
            "end": finish,
            "duration": finish - cursor,
            "transition": "continue" if i == 0 else "from_previous_pose"
        })
        cursor = finish
    return {"ok": true, "duration": duration, "steps": steps}

func action_at(plan_data: Dictionary, seconds: float) -> String:
    var steps: Array = plan_data.get("steps", [])
    if steps.is_empty():
        return "repos"
    var t: float = maxf(seconds, 0.0)
    for step in steps:
        if t < float(step["end"]):
            return str(step["action"])
    return str(steps[-1]["action"])
