# KARMA ONE — registre de validation et verrouillage

Date : 2026-11-18. Ce registre distingue correction committée et validation exécutée. Ne pas annoncer une étape comme verrouillée sans tests réussis.

## Étape 9G — Contrat de validation humaine / export PNG

- **Statut : EN COURS (non verrouillée)**
- **Branche :** `karma/step09g-review-assertion-fix-20261118`
- **Base :** `7d211dc8216375bd12d0a5233fecd07877f25b34`
- **Commit correctif :** `f3c001178cf0e9d99f67e8245347716635264c2e`
- **Cause observée :** workflow 44248504849, étape « Test real image service protocol without GPU calls » ; `test_reference_review_pipeline.gd:69` attendait « Export bloqué » mais `_export_png_sequence()` produit « Export bloque ».
- **Correction :** assertion PNG alignée sur la sortie réelle ; aucun changement au moteur ni à la règle d'approbation obligatoire.
- **Preuves antérieures :** dans ce workflow, `REMOTE_POSE_BRIEFS_OK` et `HF_BATCH_FALLBACK_OK` ; ce sont des tests simulés, non des preuves d'accès réel au GPU.
- **Tests ciblés à exécuter localement, sans APK :** `Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script res://tests/test_reference_review_pipeline.gd` ; `Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script res://tests/test_friendly_studio.gd` ; `Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script res://tests/test_hf_batch_fallback.gd`.
- **Workflow de tests sans APK :** `.github/workflows/test-9g-review-only.yml` ajouté au commit `e56d718fe3197d7560cd85fd5c307fcd982cb6f1` (déclenchement sur push de la branche 9G). Vérifie trois tests Godot avec logs et sentinelles. Aucune commande de compilation APK dans ce workflow.
- **Résultat des nouveaux tests :** NON CONFIRMÉ ; ne pas supposer qu'un run a eu lieu ou réussi sans consulter GitHub Actions.
- **Acquis préservés :** refus d'export sans approbation, rejet de scène, empreinte de validation et parcours existant ; aucune fusion ni reconstruction.
- **Limites :** pas de test Android Xiaomi, pas de preuve d'export MP4 ni de service IA réel ; aucun APK actuel produit.
- **Dépendances :** inventaire des branches divergentes avant intégration des étapes 10–12.
- **Régression :** non vérifiée depuis le correctif.
- **Règle :** ne pas modifier les étapes validées sans justification et nouveaux tests. Ne pas déclencher de compilation APK sans autorisation explicite.

## Étape 10 — Agents et orchestrateur
- **Statut : INVENTAIRE STATIQUE PARTIEL ; NON VALIDÉ**. La validation dynamique 9G reste une dépendance.
- **Entrée Android :** `scripts/storyboard.gd` instancie `scripts/universal_board_pipeline.gd`, reçoit `stage_changed` et transmet les états à `session_agent`.
- **Planification :** `scripts/board_generation_plan.gd` fournit `remote_frame`, `make_plan`, `validate_drawings` et `calculate_density`.
- **Génération :** `scripts/universal_board_pipeline.gd` choisit `scripts/local_studio_generator.gd` ou `scripts/hf_studio_generator.gd` selon `local_inference` ; ces moteurs sont déjà présents, pas à recréer.
- **État persistant :** `scripts/karma_studio_session.gd` sauvegarde `karma_agents.json` via fichier temporaire puis renommage. `record_frame` initialise `human_approved=false` ; `record_user_approval` inscrit l'empreinte et l'approbation ; `record_video_result` exige un fichier MP4 existant avec signature `ftyp` et taille supérieure à 1024 octets avant de déclarer `encoded_native`.
- **Risques à vérifier :** propagation des erreurs des moteurs et repli réel ; persistance après fermeture Android ; cohérence empreinte/validation après modification des dessins ; refus d'export si approbation périmée ; confirmation MP4 réelle. L'existence des méthodes ne prouve pas ces comportements en production.
- **Actions suivantes :** exécuter les tests Godot sans APK, puis tests ciblés d'intégration sur la même branche ; ne pas fusionner les branches divergentes sans inventaire de leurs changements.
- **Aucune compilation APK autorisée par ce registre.**

## Étape 11 — Génération universelle
- **Statut : À FAIRE** ; dépend de la vérification des moteurs et des flux Android.

## Étape 12 — Qualité visuelle et Android
- **Statut : À FAIRE** ; les commits de la branche qualité divergent de 9F et ne sont pas présumés fusionnés.
