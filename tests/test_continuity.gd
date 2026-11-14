extends SceneTree
# Executable with: godot --headless --path . --script res://tests/test_continuity.gd
func _initialize() -> void:
 var validator = load("res://scripts/frame_continuity_check.gd")
 var black := Image.create(32, 32, false, Image.FORMAT_RGBA8)
 black.fill(Color.BLACK)
 var white := Image.create(32, 32, false, Image.FORMAT_RGBA8)
 white.fill(Color.WHITE)
 var still: Dictionary = validator.inspect([black, black.duplicate()])
 assert(bool(still["ok"]))
 assert(float(still["average_difference"]) < 0.003)
 var changed: Dictionary = validator.inspect([black, white])
 assert(bool(changed["ok"]))
 assert(float(changed["average_difference"]) > 0.9)
 var loop: Dictionary = validator.inspect([black, white], true)
 assert(bool(loop["loop_checked"]))
 assert((loop["pairs"] as Array).size() == 2)
 print("PASS: continuity, static frame detection, loop seam")
 quit(0)
