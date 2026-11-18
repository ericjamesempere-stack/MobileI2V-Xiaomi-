extends SceneTree
const ADAPTER = preload("res://scripts/karma_step09_storyboard_adapter.gd")
func _initialize() -> void:
 var adapter = ADAPTER.new()
 assert(adapter.begin("step09d").get("ok", false))
 assert(not adapter.accept_generated_frames([], [], "remote").get("ok", false))
 assert(adapter.accept_pose_plan(8, true).get("ok", false))
 var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
 image.fill(Color.WHITE)
 assert(not adapter.accept_generated_frames([image, image], [], "remote").get("ok", false))
 assert(not adapter.approve("fingerprint", true).get("ok", false))
 assert(not adapter.may_export("fingerprint").get("ok", false))
 print("STEP09_STORYBOARD_ADAPTER_PASS")
 quit(0)
