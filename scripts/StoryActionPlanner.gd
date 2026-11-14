extends RefCounted
class_name StoryActionPlanner

# Explicit action beats for the animation engine. This is a motion plan,
# not rendered artwork. Unknown verbs are flagged, never silently made idle.
const ACTIONS := {
    "cour": "run", "run": "run", "sprint": "run",
    "march": "walk", "walk": "walk",
    "tomb": "fall", "fall": "fall", "trébuch": "fall", "trebuch": "fall",
    "saut": "jump", "jump": "jump", "bond": "jump",
    "dans": "dance", "danc": "dance",
    "salut": "wave", "wave": "wave",
    "roul": "travel", "driv": "travel", "avanc": "travel", "repart": "travel",
    "vol": "fly", "fly": "fly", "atterr": "land", "land": "land",
    "arrêt": "stop", "arret": "stop", "stop": "stop"
}

static func action_for(description: String) -> String:
    var lowered := description.to_lower()
    for fragment in ACTIONS.keys():
        if lowered.contains(str(fragment)):
            return str(ACTIONS[fragment])
    return "unsupported"

static func beats_for(action: String) -> Array:
    match action:
        "run":
            return ["contact_left", "flight", "contact_right", "flight"]
        "walk":
            return ["contact_left", "passing", "contact_right", "passing"]
        "fall":
            return ["upright", "lose_balance", "descending", "ground"]
        "jump":
            return ["crouch", "takeoff", "airborne", "landing"]
        "dance":
            return ["step_left", "center", "step_right", "center"]
        "wave":
            return ["arm_down", "arm_up", "hand_swing", "arm_down"]
        "travel", "fly":
            return ["depart", "accelerate", "cruise", "arrive"]
        "land":
            return ["approach", "descent", "touchdown", "settle"]
        "stop":
            return ["moving", "braking", "slowing", "still"]
        _:
            return []

static func plan(project: Dictionary, fps: int = 12) -> Dictionary:
    if fps < 1 or fps > 60:
        return {"ok": false, "error": "invalid_fps"}
    var result: Dictionary = project.duplicate(true)
    var scenes: Array = result.get("scenes", [])
    for i in range(scenes.size()):
        var scene: Dictionary = scenes[i]
        var action := action_for(str(scene.get("description", "")))
        var beats := beats_for(action)
        var frames := maxi(1, roundi(float(scene.get("duration_seconds", 1.0)) * float(fps)))
        scene["motion_action"] = action
        scene["motion_beats"] = beats
        scene["required_unique_frames"] = frames
        scene["motion_supported"] = action != "unsupported"
        scene["motion_status"] = "planned_not_rendered" if action != "unsupported" else "unsupported_action"
        scenes[i] = scene
    result["scenes"] = scenes
    result["motion_plan_fps"] = fps
    result["motion_rendered"] = false
    return {"ok": true, "project": result}
