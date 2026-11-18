# Inventaire des agents KARMA ONE

Base V60 inspectée au 18 novembre 2026. HEAD `656d13907e593db060309cffda505da76d507b4c`. Le commit demandé `f040951cd249be63c310246c882bd2260fe67ef4` est son ancêtre. Origines de comparaison : V53 `769614a`, V54 `e824aa4`, Autopilot V2 `3444b7c`, V55 `a3e3180`, V56 `cdb4f5f`, V57 `8176fb4`, V58 `223708d`, V59 `0c95f86`. La branche divergente `karma-one/fix-43374551499-1` ajoute un correctif de rendu du rig dans `scripts/export_mp4.gd`. Elle reste distincte du parcours MobileI2V testé ici.

## Gestion du développement

| Composant existant | Contrat et appelants | Test et état |
|---|---|---|
| `autopilot/supervisor.py` | Valide et ordonne le DAG versionné de `tasks.json`. Exécute les contrôles Git, Godot, vidéo, APK et lecture CI selon le rôle. CLI et workflow Android. | `test_autopilot.py` et DAG MobileI2V effectivement lancés. |
| `autopilot/agent_registry.json` | Treize rôles V2 conservés. Les règles exécutables sont les correspondances rôle/exécuteur et rôle/test de `supervisor.py`. | Validation des tâches et refus des commandes arbitraires dans `test_autopilot.py`. |
| `scripts/karma_agent_supervisor.gd` | `check_engine`, `new_session`, `advance`, `may_export`. Les assertions de provenance et d’approbation servent de contrôle de développement. | `test_karma_agent_supervisor.gd` relié au DAG. Le parcours Android utilise ses gardes préexistants. |
| `scripts/karma_guard_agent.gd` | `authorize`, `validate_message`. Le laboratoire de contrôle et l’adaptateur `autopilot/review_checks.gd` appellent le garde. | `test_karma_control_lab.gd`, refus d’une fusion protégée et contrôles des autorisations. |
| `scripts/karma_diagnostic_agent.gd` | `diagnose` classe les incidents. Appelé par `karma_agent_control_lab.gd`. | Contrats et collaboration couverts par `test_karma_control_lab.gd`. La qualification automatique d’un incident de production demeure ouverte. |
| `scripts/karma_recovery_agent.gd` | `plan` choisit une reprise bornée sur preuves. Appelé par `karma_agent_control_lab.gd`. | Contrats couverts par `test_karma_control_lab.gd`. La reprise des tests sur disque est gérée par le superviseur Python. |
| `scripts/karma_benchmark_agent.gd` | `summarize` agrège des mesures attestées. Appelé par les laboratoires de contrôle et d’apprentissage. | Contrats testés avec des mesures de fixture. |
| `scripts/karma_optimizer_agent.gd` | `propose` compare les mesures avant/après. Appelé par le laboratoire de contrôle. | `test_karma_control_lab.gd`. Le choix reste consultatif. |
| `scripts/karma_agent_experience.gd` | `observe`, `summarize`, `recommend`, `export_state`, `import_state`. Appelé par `karma_agent_learning_lab.gd`. | `test_karma_agent_experience.gd` et `test_karma_agent_learning_lab.gd`, avec restauration d’un instantané. Les journaux du superviseur ont leur propre schéma SQLite. |
| `scripts/karma_code_test_agent.gd` | `evaluate` compare deux rapports complets. `review_candidate_checks` évalue des reçus hors ligne réels via `review_checks.gd`, dans son propre processus Godot. | `test_karma_code_test_agent.gd`, laboratoire d’apprentissage et deux revues réelles de commits. |
| `scripts/karma_agent_control_lab.gd` et `scripts/karma_agent_learning_lab.gd` | Composent les agents existants. Le premier raccorde autorisation, diagnostic et reprise. Le second raccorde mesure, expérience et revue. | Contrats inclus dans le DAG. Les mesures de fixture restent étiquetées. |

Les rôles `inventory`, `integration`, `motion`, `storyboard`, `approval`, `qa` et `security` ont des tâches dans le DAG principal. `video` et `android` inspectent les fichiers fournis dans `artifact_tasks.json`. `vision` et `redraw` attendent une inférence réelle attestée. Les autres rôles restent déclarés au registre V2 et attendent un exécuteur dédié au pilotage.

## Parcours applicatif MobileI2V

| Composant existant | Appelants et rôle | Test et état |
|---|---|---|
| `scripts/karma_one_agents.gd`, `scripts/karma_one_orchestrator.gd` | `storyboard.gd` appelle l’orchestrateur de génération. `karma_studio_session.gd` et l’orchestrateur appellent les routines de planification. | Parse Godot et écrans existants préservés. |
| `scripts/karma_intermediate_agent.gd` | Contrat de planification et de frames intermédiaires utilisé par le pipeline Board. | `test_karma_intermediate_agent.gd` et `test_karma_intermediate_render.gd`. |
| `scripts/karma_technical_memory.gd` | Le pipeline universel réserve les tentatives d’inférence avec `begin` et les journalise avec `finish`. | `test_karma_technical_memory.gd`, état Godot déjà distinct de la mémoire du développement. |
| `scripts/storyboard.gd`, `scripts/android_image_reader.gd` et plugin Android | Sélection, retour URI décodé par le plugin, fichier privé, aperçu, état projet. Le correctif borne l’attente en cas de retour perdu. | `test_v58_photo_recovery.gd`, `test_v60_simplified_receive.gd`. Test Xiaomi en attente. |
| `scripts/universal_board_pipeline.gd`, générateurs HF/local, `chatgpt_board_bridge.gd` | Photo/idée + histoire, moteurs configurés, parcours ChatGPT assisté, planches, revue, remplacement. | Contrats et fixtures. Moteur génératif complet à vérifier sur une installation réelle. |
| `scripts/storyboard.gd` et MediaCodec natif | Revue obligatoire, blocage des dessins refusés, rendu/export H.264, lecture et partage. | Tests Godot de revue, fichier H.264 de fixture décodé avec FFmpeg. Essai MediaCodec sur Xiaomi en attente. |
