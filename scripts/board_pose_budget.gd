extends RefCounted
# V54 heuristic pose budget. This is NOT semantic image understanding.
# The user's drawing-count control remains a hard GPU budget.
func estimate(story: String, duration: float, budget: int) -> Dictionary:
    var normalized: String = story.to_lower().strip_edges()
    if normalized.is_empty() or duration <= 0.0 or budget < 1:
        return {"ok": false, "error": "Description, duree ou budget invalide."}
    var action_words: Array[String] = ["court", "courir", "run", "runs", "danse", "dance", "saute", "jump", "tombe", "fall", "falls", "tourne", "turn", "roule", "roll", "rebond", "bounce", "marche", "walk", "leve", "raise", "accroup", "crouch", "vole", "fly", "freine", "brake", "traverse", "cross"]
    var interaction_words: Array[String] = ["contre", "avec", "between", "against", "attrape", "catch", "frappe", "hit", "pousse", "push", "collision", "évite", "evite", "avoid"]
    var actions: int = 0
    var interactions: int = 0
    for word in action_words:
        if normalized.contains(word):
            actions += 1
    for word in interaction_words:
        if normalized.contains(word):
            interactions += 1
    # At least a beginning and ending pose; more action beats need more poses.
    var recommended: int = clampi(maxi(2, int(ceil(duration * 1.5)), 2 + actions * 2 + interactions), 2, 240)
    var selected: int = mini(recommended, budget)
    return {"ok": true, "recommended": recommended, "selected": selected, "budget": budget, "actions_detected": actions, "interactions_detected": interactions, "limited_by_budget": selected < recommended, "method": "keyword_heuristic_not_semantic"}
