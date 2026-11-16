extends RefCounted
# KARMA ONE multi-agent coordinator: offline, deterministic and auditable.
# Agents are specialized tasks, not independent LLMs or unauthorized web automation.
const AGENTS := ["scenario", "pose", "image", "quality", "recovery", "video"]

func plan(story: String, duration_seconds: float, image_count: int) -> Dictionary:
 if story.strip_edges().is_empty():
  return {"ok": false, "error": "Histoire manquante"}
 if image_count < 2 or image_count > 240:
  return {"ok": false, "error": "Nombre de dessins invalide"}
 var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
 var motion: Dictionary = planner.plan(story, duration_seconds)
 if not bool(motion.get("ok", false)):
  return {"ok": false, "error": str(motion.get("error", "Plan de mouvement invalide"))}
 var tasks: Array[Dictionary] = []
 tasks.append({"agent": "scenario", "task": "planifier", "status": "done"})
 tasks.append({"agent": "pose", "task": "produire_guides", "status": "pending", "count": image_count})
 tasks.append({"agent": "image", "task": "obtenir_dessins_reels", "status": "pending", "requires": "images importees ou moteur HTTPS"})
 tasks.append({"agent": "quality", "task": "verifier_continuite", "status": "pending"})
 tasks.append({"agent": "recovery", "task": "sauvegarder_et_reprendre", "status": "pending"})
 tasks.append({"agent": "video", "task": "encoder_mp4", "status": "pending", "requires": "plugin MP4 Android"})
 return {"ok": true, "agents": AGENTS, "tasks": tasks, "motion": motion, "duration_seconds": duration_seconds, "image_count": image_count}

func diagnose(error_message: String, http_status: int = 0) -> Dictionary:
 if http_status == 429 or error_message.contains("quota"):
  return {"agent": "recovery", "action": "sauvegarder_et_attendre_ou_changer_moteur", "retryable": true}
 if http_status == 502 or http_status == 503 or http_status == 504:
  return {"agent": "recovery", "action": "essayer_moteur_secondaire", "retryable": true}
 if http_status == 401 or http_status == 403:
  return {"agent": "recovery", "action": "demander_autorisation_utilisateur", "retryable": false}
 if error_message.contains("MP4") or error_message.contains("encodeur"):
  return {"agent": "video", "action": "conserver_les_png_et_proposer_avi", "retryable": false}
 return {"agent": "quality", "action": "conserver_les_resultats_et_diagnostiquer", "retryable": false}
