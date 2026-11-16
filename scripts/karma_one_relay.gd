extends RefCounted
# Offline handoff between free assistants. No API, login automation or quota bypass.
const PROVIDERS := ["ChatGPT", "Gemini", "Mistral", "Claude", "Autre"]
const ROOT := "user://projects/karma_relay"

func create_relay(story: String, seconds: float, expected_frames: int, existing_paths: Array[String], provider: String = "ChatGPT") -> Dictionary:
 if story.strip_edges().is_empty():
  return {"ok": false, "error": "Scenario manquant"}
 if expected_frames < 2 or expected_frames > 240:
  return {"ok": false, "error": "Nombre de dessins hors limites (2-240)"}
 var folder: String = ROOT.path_join("relay_%d" % Time.get_unix_time_from_system())
 var err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 if err != OK:
  return {"ok": false, "error": "Impossible de creer le dossier relais"}
 var ready: Dictionary = {}
 for p in existing_paths:
  var filename: String = p.get_file().get_basename()
  if filename.begins_with("frame_") and filename.substr(6).is_valid_int() and FileAccess.file_exists(p):
   var index: int = int(filename.substr(6))
   if index >= 0 and index < expected_frames:
    ready[index] = p
 var missing: Array[int] = []
 for i in range(expected_frames):
  if not ready.has(i):
   missing.append(i)
 var manifest: Dictionary = {
  "format": "karma-one-relay-v1",
  "story": story,
  "duration_seconds": seconds,
  "expected_frames": expected_frames,
  "ready_frames": ready.size(),
  "missing_indices": missing,
  "provider_hint": provider,
  "instructions": "Produire uniquement les dessins manquants. Meme personnage, meme cadrage, meme style. Noms frame_0000.png etc. Ne pas refaire les dessins deja valides."
 }
 var manifest_file := FileAccess.open(folder.path_join("manifest.json"), FileAccess.WRITE)
 if manifest_file == null:
  return {"ok": false, "error": "Impossible d'ecrire le manifeste"}
 manifest_file.store_string(JSON.stringify(manifest, "  "))
 manifest_file.close()
 var text_file := FileAccess.open(folder.path_join("PROMPT_A_COPIER.txt"), FileAccess.WRITE)
 if text_file == null:
  return {"ok": false, "error": "Impossible d'ecrire le prompt"}
 text_file.store_string("KARMA ONE - RELAIS SANS API\nScenario : " + story + "\nDuree : " + str(seconds) + " s\nDessins attendus : " + str(expected_frames) + "\nDessins manquants : " + str(missing) + "\nProduis seulement les images manquantes. Garde l'identite et le style du personnage des images de reference fournies. Nomme chaque image frame_XXXX.png avec l'indice demande. Ne pretends pas avoir genere des images si tu ne peux pas les produire.\n")
 text_file.close()
 return {"ok": true, "folder": folder, "missing": missing, "ready": ready.size()}
