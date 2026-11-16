extends RefCounted
# Merge named storyboard frames without renumbering or overwriting existing work.
# No API required. Accept only frame_NNNN.png/jpg/jpeg/webp.
const ROOT := "user://projects/karma_merged"

func restore(folder: String) -> Dictionary:
 var ledger_path: String = folder.path_join("merge_state.json")
 if not FileAccess.file_exists(ledger_path):
  return {"ok": false, "error": "Journal de reprise introuvable"}
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ledger_path))
 if not data is Dictionary or int(data.get("version", 0)) != 1:
  return {"ok": false, "error": "Journal de reprise invalide"}
 var saved_paths: Array = data.get("paths", [])
 var saved_indices: Array = data.get("indices", [])
 if saved_paths.is_empty() or saved_paths.size() != saved_indices.size():
  return {"ok": false, "error": "Journal incomplet"}
 var paths: Array[String] = []
 var indices: Array[int] = []
 var seen: Dictionary = {}
 for i in range(saved_paths.size()):
  var p: String = str(saved_paths[i])
  if not FileAccess.file_exists(p):
   return {"ok": false, "error": "Dessin manquant : " + p.get_file()}
  var image := Image.new()
  if image.load(p) != OK or image.is_empty():
   return {"ok": false, "error": "Dessin illisible : " + p.get_file()}
  var index: int = int(saved_indices[i])
  if index < 0 or index >= 240 or seen.has(index):
   return {"ok": false, "error": "Indices invalides ou dupliques dans le journal"}
  # Never trust a journal whose frame index disagrees with the image filename.
  var basename: String = p.get_file().get_basename()
  if not basename.begins_with("frame_") or not basename.substr(6).is_valid_int() or int(basename.substr(6)) != index:
   return {"ok": false, "error": "Indice et nom du dessin incompatibles : " + p.get_file()}
  seen[index] = true
  paths.append(p)
  indices.append(index)
 var expected: int = clampi(int(data.get("expected_frames", 0)), 0, 240)
 var present: Dictionary = {}
 for idx in indices:
  present[idx] = true
 var missing: Array[int] = []
 for idx in range(maxi(expected, indices.max() + 1)):
  if not present.has(idx):
   missing.append(idx)
 return {"ok": true, "paths": paths, "indices": indices, "missing": missing, "complete": missing.is_empty() and (expected <= 0 or indices.size() >= expected)}

func merge(folder: String, existing: Array[String], limit: int = 240, expected_frames: int = 0) -> Dictionary:
 var dir := DirAccess.open(folder)
 if dir == null:
  return {"ok": false, "error": "Dossier inaccessible"}
 var frame_paths: Dictionary = {}
 for path in existing:
  var base: String = path.get_file().get_basename()
  if base.begins_with("frame_") and base.substr(6).is_valid_int() and FileAccess.file_exists(path):
   var idx: int = int(base.substr(6))
   if idx >= 0 and idx < limit:
    var old_image := Image.new()
    if old_image.load(path) == OK and not old_image.is_empty():
     frame_paths[idx] = path
 var added: int = 0
 var duplicates: int = 0
 var rejected: int = 0
 var names: PackedStringArray = dir.get_files()
 names.sort()
 # A monotonic suffix avoids overwriting merges made during the same second.
 var output: String = ROOT.path_join("merge_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
  return {"ok": false, "error": "Impossible de creer le dossier de travail"}
 for name in names:
  var ext: String = name.get_extension().to_lower()
  if not (ext in ["png", "jpg", "jpeg", "webp"]):
   continue
  var stem: String = name.get_basename()
  if not stem.begins_with("frame_") or not stem.substr(6).is_valid_int():
   rejected += 1
   continue
  var idx: int = int(stem.substr(6))
  if idx < 0 or idx >= limit:
   rejected += 1
   continue
  if frame_paths.has(idx):
   duplicates += 1
   continue
  var img := Image.new()
  if img.load(folder.path_join(name)) != OK or img.is_empty():
   rejected += 1
   continue
  var target: String = output.path_join("frame_%04d.png" % idx)
  if img.save_png(target) != OK:
   rejected += 1
   continue
  frame_paths[idx] = target
  added += 1
 if frame_paths.is_empty():
  return {"ok": false, "error": "Aucun dessin valide au format frame_0000.png"}
 var indices: Array[int] = []
 for idx in frame_paths.keys():
  indices.append(int(idx))
 indices.sort()
 var missing: Array[int] = []
 for i in range(maxi(indices[-1] + 1, mini(limit, expected_frames))):
  if not frame_paths.has(i):
   missing.append(i)
 var ordered: Array[String] = []
 for idx in indices:
  ordered.append(str(frame_paths[idx]))
 var ledger := FileAccess.open(output.path_join("merge_state.json"), FileAccess.WRITE)
 if ledger == null:
  return {"ok": false, "error": "Impossible de sauvegarder le journal de fusion"}
 var state := {"version": 1, "expected_frames": expected_frames, "indices": indices, "paths": ordered, "missing": missing, "complete": missing.is_empty() and (expected_frames <= 0 or indices.size() >= expected_frames)}
 ledger.store_string(JSON.stringify(state, "  "))
 ledger.flush()
 ledger.close()
 return {"ok": true, "paths": ordered, "indices": indices, "missing": missing, "added": added, "duplicates": duplicates, "rejected": rejected, "folder": output, "complete": missing.is_empty() and (expected_frames <= 0 or indices.size() >= expected_frames)}
