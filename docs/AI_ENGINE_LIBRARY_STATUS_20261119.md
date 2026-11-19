# KARMA ONE — bibliothèque et raccordement des moteurs IA

Date : 2026-11-19. Inventaire technique issu du code existant et du test réel sur Xiaomi 14T Pro. **Aucun modèle n'est déclaré fonctionnel sans inférence réelle.**

## Contrats existants

- `scripts/karma_module_registry.gd` : rôles `vision`, `image`, `motion`, `encode` ; `module_probe` et `module_run` obligatoires ; module sélectionnable seulement si `inference_verified=true`.
- `scripts/local_studio_generator.gd` : transport HTTP local exclusivement `127.0.0.1`, MNN Chat `/v1/models` port 8080, Local Dream `/health` port 8081. Aucune inférence intégrée démontrée par ce transport.
- `scripts/hf_studio_generator.gd` : adaptateur distant existant, soumis aux conditions, disponibilité, quotas et consentement explicite pour les images.
- Pipeline storyboard, images intermédiaires et MP4 : tests d'intégration réussis avec inférence simulée, pas avec moteur neuronal Android réel.

## Réutilisation vérifiée des agents précédents — étape 1/4

- `native/mnnarm64/src/KarmaClipEncoder.java` : `encodePrompt` utilise `tokenizeClip`, charge le graphe CLIP et récupère deux tenseurs 77×768. Validation stricte des formes et des valeurs finies. **Code présent, pas d'exécution sur Xiaomi démontrée**.
- `native/mnnarm64/src/KarmaSdInference.java` : `generatePrompt` relie déjà tokenizer + CLIP à `generate`, qui exécute UNet batch=2, DDIM puis VAE et écrit un PNG 512×512. L'ancien commentaire de classe « Not text-to-image yet » est obsolète au regard de cette méthode ; l'exécution complète n'est pas prouvée sur appareil.
- `native/mnnarm64/src/KarmaMnnBridge.java` : chargement natif des bibliothèques et primitives `loadGraph`, `runGraph`, `setIntInput`, `setFloatInput`, `getFloatOutput`, `tokenizeClip`, `ddimStep`. **Le chargement des bibliothèques ne prouve pas celui des poids**.
- `.github/workflows/validate-sd15-mnn-runtime.yml` : référence explicitement l'artefact `karma-sd15-real-mnn-models` du run `44420581040`. Le workflow de validation est verrouillé sur la branche de consolidation ; ne pas le déclencher sur la branche courante sans adaptation vérifiée.
- Comparaison GitHub `karma/step12-consolidation-20261118...karma/step04-clip-parity-validated-20261119` : branche actuelle **31 commits en avance, 0 en retard** lors de l'audit. Pas de fusion nécessaire depuis cette branche.

**Point de blocage à traiter en premier :** déterminer où les poids MNN et le tokenizer sont stockés, vérifier leur disponibilité et leur licence, puis trouver le point d'appel Android/Godot de `KarmaSdInference.generatePrompt`. Ne pas coder un second pipeline de diffusion. Un artefact CI ne signifie pas que les modèles sont présents sur le téléphone.

## Bibliothèque — disponibilité et exigences

| Fonction | Candidat | Statut prouvé | Condition avant activation |
| --- | --- | --- | --- |
| Vision locale | MNN Chat, API locale | Indisponible sur téléphone testé (port 8080) | Installer/lancer un service compatible, charger un modèle vision, vérifier une requête réelle |
| Dessin local | Local Dream, API locale | Indisponible sur téléphone testé (port 8081) | Installer/lancer un service compatible, charger un modèle image, générer une image réelle |
| MNN natif ARM64 | libMNN, libllm, libkarma_mnn | Présence des composants dans APK vérifiée par CI | Vérifier pont JNI, modèle et tokenizer, chargement, génération réelle, consommation mémoire et thermiques |
| Images en ligne | Adaptateur Hugging Face existant | Tests de protocole simulés, pas de disponibilité garantie | Consentement, endpoint réel, réponse image, quotas et gestion d'échec |
| Animation | Storyboard + images intermédiaires | Pipeline simulé et export MP4 validés en CI | Génération réelle de poses cohérentes et test sur Xiaomi |
| Encodage | Export MP4 existant | Export de test validé en CI Linux | Test Android sur appareil, décodage/lecture du fichier |

## Ordre d'intégration (ne pas reconstruire)

1. Conserver la version APK validée et ses sources. Ne pas fusionner de branche ni relancer un build avant un correctif démontré.
2. Établir un inventaire des modèles, fichiers, licences, RAM et formats effectivement disponibles. Un modèle non téléchargé ne doit jamais être affiché « prêt ».
3. Privilégier le pont JNI MNN déjà empaqueté : rechercher un point d'entrée d'inférence exploitable dans l'application, plutôt que supposer qu'une bibliothèque native lance un serveur HTTP.
4. Si une application externe est nécessaire, tester sa présence, son API exacte et la possibilité réelle de l'utiliser depuis KARMA ONE. Ne pas supposer qu'une application MNN Chat expose un serveur.
5. Valider une inférence vision sur image réelle ; puis une génération d'image réelle ; puis la continuité entre images ; enfin le MP4 Android.
6. Le registre de modules ne marque `verified=true` qu'après un `module_probe` avec `inference_verified=true` fondé sur une exécution réelle, pas sur une simple réponse HTTP /health.
7. Afficher à l'utilisateur un résumé court : « Moteurs locaux non prêts », les deux services manquants, et les actions à entreprendre. Conserver les détails réseau dans les diagnostics.

## Règles de sûreté et budget

- Zéro envoi de photos, prompts ou données vers un fournisseur externe sans autorisation explicite.
- Pas de contournement des quotas, pas de comptes multiples pour les contourner, pas de modèles ou API déclarés gratuits sans vérification.
- Un moteur en erreur d'authentification, de quota, de sécurité ou de requête invalide ne doit pas être relancé automatiquement.
- La compilation CI ne prouve pas la compatibilité du modèle avec le Xiaomi 14T Pro.

## État du test utilisateur

L'application s'ouvre, l'importation de photo et la navigation fonctionnent. L'analyse locale et le dessin local échouent avec HTTP 0 / réseau 2 sur `127.0.0.1:8080` et `127.0.0.1:8081`. Le téléphone signale l'absence des applications MNN Chat et Local Dream. Le projet est conservé ; aucune génération neuronale réelle n'est encore validée.
