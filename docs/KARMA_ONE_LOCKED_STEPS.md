# KARMA ONE — registre de validation et verrouillage

Date : 2026-11-18. Ce registre distingue correction committée et validation exécutée. Ne pas annoncer une étape comme verrouillée sans tests réussis.

## Étape 9G — Contrat de validation humaine / export PNG

- **Statut : VERROUILLÉE pour les contrôles Godot 9G**
- **Branche :** `karma/step09g-review-assertion-fix-20261118`
- **Base :** `7d211dc8216375bd12d0a5233fecd07877f25b34`
- **Commit correctif :** `f3c001178cf0e9d99f67e8245347716635264c2e`
- **Cause observée :** workflow 44248504849, étape « Test real image service protocol without GPU calls » ; `test_reference_review_pipeline.gd:69` attendait « Export bloqué » mais `_export_png_sequence()` produit « Export bloque ».
- **Correction :** assertion PNG alignée sur la sortie réelle ; aucun changement au moteur ni à la règle d'approbation obligatoire.
- **Preuves antérieures :** dans ce workflow, `REMOTE_POSE_BRIEFS_OK` et `HF_BATCH_FALLBACK_OK` ; ce sont des tests simulés, non des preuves d'accès réel au GPU.
- **Tests ciblés à exécuter localement, sans APK :** `Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script res://tests/test_reference_review_pipeline.gd` ; `Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script res://tests/test_friendly_studio.gd` ; `Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script res://tests/test_hf_batch_fallback.gd`.
- **Workflow de tests sans APK :** `.github/workflows/test-9g-review-only.yml` ajouté au commit `e56d718fe3197d7560cd85fd5c307fcd982cb6f1` (déclenchement sur push de la branche 9G). Vérifie trois tests Godot avec logs et sentinelles. Aucune commande de compilation APK dans ce workflow.
- **Résultat des nouveaux tests :** succès des contrôles Godot au commit `8b3a795ec900861c8878dfbdf3b7185efcf100b9`. [Exécution 44257383744](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44257383744).
- **Acquis préservés :** refus d'export sans approbation, rejet de scène, empreinte de validation et parcours existant ; aucune fusion ni reconstruction.
- **Limites :** pas de test Android Xiaomi, pas de preuve d'export MP4 ni de service IA réel ; aucun APK actuel produit.
- **Dépendances :** inventaire des branches divergentes avant intégration des étapes 10–12.
- **Régression :** contrôles 9G exécutés avec succès au commit ci-dessus.
- **Règle :** ne pas modifier les étapes validées sans justification et nouveaux tests. Ne pas déclencher de compilation APK sans autorisation explicite.

## Étape 10 — Agents et orchestrateur

- **Statut** — VERROUILLÉE pour les contrôles Godot et Android automatisés.
- **Commit d’intégration** — `bfab3df999f38df6d2bcf401ff76da7ea02cd97d`. Work Gallery, repli V61 avec désactivation, diagnostics visuels consultatifs et contrôle 9G réutilisé pour l’approbation des exports.
- **Contrôles locaux** — 36 scripts Godot 4.6.3, contrôles Python et transports simulés réussis. Le MP4 de régression a été généré puis décodé sur Linux avec FFmpeg.
- **Premier contrôle CI** — Le job Godot 4.5.2 a passé les contrôles de revue 9G et le registre des agents, puis le test d’intégration MP4 a échoué car FFmpeg était absent. Le job Android s’est arrêté avant les tests unitaires, sur HTTP 429 lors de la résolution des dépendances Gradle. [Exécution 44260572129](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44260572129).
- **Correctifs CI** — Installation conditionnelle de FFmpeg avec vérification SHA256 reprise du workflow du dépôt. Nouvelle tentative Gradle uniquement si Maven Central renvoie HTTP 429.
- **Contrôles de validation** — Réussite des jobs Godot 4.5.2 (36 scripts, contrôles Python et transports simulés) et Android (profil ARM64 et `testDebugUnitTest`) au commit `dba278abd8761610c1e863a42bc32267790bd6de`. [Exécution 44261921954](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44261921954).
- **Exécution ARM64** — Tentative unique sur `0731367885df4fd773e11ca557c869c8c88b1281`. Arrêt avant export APK au test `test_friendly_studio.gd:51` dans « Test real image service protocol without GPU calls ». [Exécution 44262509434](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44262509434).
- **Cause et correction** — Le partage des données Godot entre tests reproduit l’assertion quand Friendly Studio charge la planche persistée par V60. Le workflow attribue maintenant à chacun des sept scripts de cette étape son propre `XDG_DATA_HOME`. Les sept scripts passent localement sous Godot 4.6.3, même avec la fixture V60 toujours présente dans le répertoire parent.
- **Artefact de diagnostic** — ID 14409460942, expiration le 2 décembre 2026 à 07:58:07 UTC. [Journaux du build](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44262509434/artifacts/14409460942).
- **APK** — Aucun APK produit. Validation matérielle Xiaomi 14T Pro à effectuer.

## Étape 11 — Génération universelle
- **Statut : À FAIRE** ; dépend de la vérification des moteurs et des flux Android.

## Étape 12 — Qualité visuelle et Android
- **Statut : À FAIRE** ; les commits de la branche qualité divergent de 9F et ne sont pas présumés fusionnés.
