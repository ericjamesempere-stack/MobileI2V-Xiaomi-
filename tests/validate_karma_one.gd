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
  if not resource is GDScript or not (resource as GDScript).can_instantiate():
   printerr("INVALID SCRIPT: ", path)
   errors += 1
  else:
   print("VALID SCRIPT: ", path)
 var main_scene: Resource = load("res://scenes/main.tscn")
 if not main_scene is PackedScene:
  printerr("INVALID MAIN SCENE")
  errors += 1
 else:
  print("VALID MAIN SCENE")
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
 var duplicate_source: String = str(second.get("paths", [])[0])
 var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(duplicate_source)
 var duplicate_merge: Dictionary = merger.merge(folder, prior, 240, 4)
 if not bool(duplicate_merge.get("ok", false)) or int(duplicate_merge.get("duplicates", 0)) < 2:
  printerr("FAILED: duplicate frame protection ", duplicate_merge)
  return 1
 if FileAccess.get_file_as_bytes(duplicate_source) != original_bytes:
  printerr("FAILED: existing frame was overwritten")
  return 1
 var tampered_folder: String = str(second.get("folder", ""))
 var ledger_path: String = tampered_folder.path_join("merge_state.json")
 var original_ledger: String = FileAccess.get_file_as_string(ledger_path)
 var tampered_data: Variant = JSON.parse_string(original_ledger)
 if not tampered_data is Dictionary:
  return 1
 var altered_indices: Array = tampered_data.get("indices", []).duplicate()
 altered_indices[0] = 99
 tampered_data["indices"] = altered_indices
 var tampered_file := FileAccess.open(ledger_path, FileAccess.WRITE)
 if tampered_file == null:
  return 1
 tampered_file.store_string(JSON.stringify(tampered_data))
 tampered_file.close()
 var rejected_restore: Dictionary = merger.restore(tampered_folder)
 var original_file := FileAccess.open(ledger_path, FileAccess.WRITE)
 if original_file == null:
  return 1
 original_file.store_string(original_ledger)
 original_file.close()
 if bool(rejected_restore.get("ok", false)):
  printerr("FAILED: tampered frame indices were accepted")
  return 1
 print("PASS: missing frames, restore, multi-batch merge, corrupt replacement and duplicate protection and tampered journal rejection")
 return 0
