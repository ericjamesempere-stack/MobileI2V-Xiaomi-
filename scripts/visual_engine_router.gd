extends RefCounted
# Explicit capabilities. Routing is not evidence that a model is installed.
const ENGINES := {
    "rig_2d": {"requires_model": false, "capabilities": ["pose", "walk", "run", "dance", "stand", "fall"], "implemented": true},
    "reference_redraw": {"requires_model": true, "capabilities": ["novel_view", "occlusion", "redraw"], "implemented": false},
    "transformation": {"requires_model": true, "capabilities": ["morph", "creature", "new_anatomy"], "implemented": false},
    "scene_generation": {"requires_model": true, "capabilities": ["environment", "objects", "interaction"], "implemented": false},
    "frame_interpolation": {"requires_model": true, "capabilities": ["interpolate"], "implemented": false},
    "mp4_export": {"requires_model": false, "capabilities": ["encode"], "implemented": true}
}
const GENERATIVE_ACTIONS := ["transformation", "metro", "football", "nouvelle_scene", "inconnu"]

func select_engine(action: String, has_reference: bool = true) -> Dictionary:
    var engine: String = "rig_2d"
    if action == "transformation":
        engine = "transformation"
    elif action == "metro" or action == "football" or action == "nouvelle_scene":
        engine = "scene_generation"
    elif action == "inconnu":
        engine = "reference_redraw"
    var spec: Dictionary = ENGINES[engine]
    var warnings: Array[String] = []
    if not has_reference:
        warnings.append("Image de personnage manquante.")
    if not bool(spec["implemented"]):
        warnings.append("Moteur %s non installe : ne pas generer de fausses images." % engine)
    return {"engine": engine, "implemented": bool(spec["implemented"]), "requires_model": bool(spec["requires_model"]), "warnings": warnings, "status": "ready" if bool(spec["implemented"]) and has_reference else "blocked"}

func get_capabilities() -> Dictionary:
    return ENGINES.duplicate(true)
