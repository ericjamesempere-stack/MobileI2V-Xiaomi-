extends SceneTree

func _initialize() -> void:
 var scripts: Array[String] = [
  "res://scripts/storyboard.gd",
  "res://scripts/karma_one_merge.gd",
  "res://scripts/karma_one_relay.gd",
  "res://scripts/karma_one_agents.gd",
  "res://scripts/karma_one_orchestrator.gd",
  "res://scripts/image_sequence_generator.gd",
  "res://scripts/story_motion_planner.gd",
  "res://scripts/export_mp4.gd"
 ]
 var errors: int = 0
 for path in scripts:
  var resource: Resource = load(path)
  if not resource is GDScript or not (resource as GDScript).is_valid():
   printerr("INVALID SCRIPT: ", path)
   errors += 1
  else:
   print("VALID SCRIPT: ", path)
 if errors > 0:
  quit(1)
 else:
  print("KARMA ONE: all selected scripts parsed successfully")
  quit(0)
