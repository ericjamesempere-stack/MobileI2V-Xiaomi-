extends SceneTree
class FakeModule extends RefCounted:
    var passes: bool = true
    func module_probe() -> Dictionary:
        return {"ok": passes, "inference_verified": passes}
    func module_run(payload: Dictionary) -> Dictionary:
        return {"ok": passes, "value": payload.get("value", "")}
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var registry: RefCounted = load("res://scripts/karma_module_registry.gd").new()
    var first := FakeModule.new()
    var backup := FakeModule.new()
    assert(not registry.register_module("image", "cloud", first, {"offline": false})["ok"])
    assert(not registry.choose("image")["ok"])
    assert(registry.register_module("image", "a-primary", first, {"offline": true})["ok"])
    assert(registry.register_module("image", "b-backup", backup, {"offline": true})["ok"])
    assert(not registry.choose("image")["ok"], "Probe must not imply verified inference")
    assert((await registry.probe_module("image:a-primary"))["ok"])
    assert((await registry.probe_module("image:b-backup"))["ok"])
    assert(registry.choose("image")["key"] == "image:a-primary")
    first.passes = false
    assert(not (await registry.run_selected("image:a-primary", {"value": "x"}))["ok"])
    assert(registry.choose("image")["key"] == "image:b-backup")
    assert((await registry.run_selected("image:b-backup", {"value": "ok"}))["value"] == "ok")
    print("KARMA_MODULE_REGISTRY_OK")
    quit(0)
