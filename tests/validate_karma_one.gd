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
 errors += _test_merge_resume()
 if errors > 0:
  quit(1)
 else:
  print("KARMA ONE: all selected scripts parsed successfully")
  quit(0)

func _test_merge_resume() -> int:
 var folder: String = "user://karma_validation_input_%d" % Time.get_ticks_usec()
 var err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 if err != OK:
  printerr("Could not create test folder")
  return 1
 var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
 img.fill(Color(0.2, 0.4, 0.6))
 for index in [0, 2]:
  if img.save_png(folder.path_join("frame_%04d.png" % index)) != OK:
   printerr("Could not create test frame")
   return 1
 var merger: RefCounted = load("res://scripts/karma_one_merge.gd").new()
 var empty: Array[String] = []
 var first: Dictionary = merger.merge(folder, empty, 240, 4)
 if not bool(first.get("ok", false)) or bool(first.get("complete", true)) or first.get("missing", []) != [1, 3]:
  printerr("FAILED: missing frame detection ", first)
  return 1
 var restored: Dictionary = merger.restore(str(first.get("folder", "")))
 if not bool(restored.get("ok", false)) or restored.get("missing", []) != [1, 3]:
  printerr("FAILED: restore frame indices ", restored)
  return 1
 img.fill(Color(0.8, 0.2, 0.1))
 for index in [1, 3]:
  if img.save_png(folder.path_join("frame_%04d.png" % index)) != OK:
   return 1
 var prior: Array[String] = []
 for path in first.get("paths", []):
  prior.append(str(path))
 var second: Dictionary = merger.merge(folder, prior, 240, 4)
 if not bool(second.get("ok", false)) or not bool(second.get("complete", false)) or second.get("indices", []) != [0, 1, 2, 3]:
  printerr("FAILED: multi-batch merge ", second)
  return 1
 var final_restore: Dictionary = merger.restore(str(second.get("folder", "")))
 if not bool(final_restore.get("ok", false)) or not bool(final_restore.get("complete", false)):
  printerr("FAILED: complete storyboard restoration ", final_restore)
  return 1
 var broken_folder: String = folder.path_join("damaged")
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(broken_folder)) != OK:
  return 1
 var bad_path: String = broken_folder.path_join("frame_0001.png")
 var broken := FileAccess.open(bad_path, FileAccess.WRITE)
 if broken == null:
  return 1
 broken.store_string("not a png")
 broken.close()
 var broken_paths: Array[String] = [bad_path]
 var replacement: Dictionary = merger.merge(folder, broken_paths, 240, 4)
 if not bool(replacement.get("ok", false)) or not replacement.get("indices", []).has(1):
  printerr("FAILED: damaged existing frame was not replaced ", replacement)
  return 1
 print("PASS: missing frames, restore, multi-batch merge and final restoration, corrupt frame replacement")
 return 0
