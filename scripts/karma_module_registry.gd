extends RefCounted
# Step 12: capability-based local module registry. Modules are replaceable only
# when they implement the same contract; research techniques are NOT plug-ins.
# This registry never starts a cloud request or claims that inference works.
const ROLES := ["vision", "image", "motion", "encode"]
const LOCAL := "local"
var modules: Dictionary = {}
var health: Dictionary = {}

func register_module(role: String, module_id: String, implementation: Object, capabilities: Dictionary) -> Dictionary:
    if not role in ROLES or module_id.strip_edges().is_empty() or implementation == null:
        return {"ok": false, "error": "invalid_module"}
    if not capabilities.get("offline", false):
        return {"ok": false, "error": "cloud_module_not_allowed"}
    if not implementation.has_method("module_probe") or not implementation.has_method("module_run"):
        return {"ok": false, "error": "module_contract_missing"}
    var key: String = role + ":" + module_id
    modules[key] = {"role": role, "id": module_id, "implementation": implementation, "capabilities": capabilities.duplicate(true)}
    health[key] = {"verified": false, "last_error": "not_probed"}
    return {"ok": true, "key": key}

func probe_module(key: String) -> Dictionary:
    if not modules.has(key):
        return {"ok": false, "error": "unknown_module"}
    var result: Variant = await modules[key]["implementation"].module_probe()
    var verified: bool = result is Dictionary and result.get("ok", false) and result.get("inference_verified", false)
    health[key] = {"verified": verified, "last_error": "" if verified else "inference_not_verified"}
    return {"ok": verified, "key": key, "error": health[key]["last_error"]}

func choose(role: String, requirements: Dictionary = {}) -> Dictionary:
    if not role in ROLES:
        return {"ok": false, "error": "invalid_role"}
    var candidates: Array = []
    for key in modules:
        var item: Dictionary = modules[key]
        if item["role"] != role or not health.get(key, {}).get("verified", false):
            continue
        var compatible: bool = true
        for feature in requirements:
            if item["capabilities"].get(feature) != requirements[feature]:
                compatible = false
                break
        if compatible:
            candidates.append(key)
    candidates.sort()
    if candidates.is_empty():
        return {"ok": false, "error": "no_verified_local_module", "role": role}
    return {"ok": true, "key": candidates[0]}

func run_selected(key: String, payload: Dictionary) -> Dictionary:
    if not modules.has(key) or not health.get(key, {}).get("verified", false):
        return {"ok": false, "error": "unverified_module"}
    var result: Variant = await modules[key]["implementation"].module_run(payload)
    if not result is Dictionary or not result.get("ok", false):
        health[key] = {"verified": false, "last_error": "runtime_failure"}
        return {"ok": false, "error": "module_failed", "key": key}
    return result
