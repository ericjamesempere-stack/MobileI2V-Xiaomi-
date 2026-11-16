extends RefCounted
# Merge named storyboard frames without renumbering or overwriting existing work.
# No API required. Accept only frame_NNNN.png/jpg/jpeg/webp.
const ROOT := "user://projects/karma_merged"

func merge(folder: String, existing: Array[String], limit: int = 240) -> Dictionary:
 var dir := DirAccess.open(folder)
 if dir == null:
  return {"ok": false, "error": "Dossier inaccessible"}
 var frame_paths: Dictionary = {}
 for path in existing:
  var base: String = path.get_file().get_basename()
  if base.begins_with("frame_") and base.substr(6).is_valid_int() and FileAccess.file_exists(path):
   var idx: int = int(base.substr(6))
   if idx >= 0 and idx < limit:
    frame_paths[idx] = path
 var added: int = 0
 var duplicates: int = 0
 var rejected: int = 0
 var names: PackedStringArray = dir.get_files()
 names.sort()
 var output: String = ROOT.path_join("merge_%d" % Time.get_ticks_usec())
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
 for i in range(indices[-1] + 1):
  if not frame_paths.has(i):
   missing.append(i)
 var ordered: Array[String] = []
 for idx in indices:
  ordered.append(str(frame_paths[idx]))
 return {"ok": true, "paths": ordered, "indices": indices, "missing": missing, "added": added, "duplicates": duplicates, "rejected": rejected, "folder": output}
