# KARMA ONE V54 — preuves d'export et recette Android
Date : 17 novembre 2026 (Europe/Paris).
Branche préservée : karma/v54-approval-safety-20261116.
Aucune reconstruction et aucune photo privée ajoutée dans cette intervention.

## Preuves historiques vérifiées
- V53, commit 769614a5913ba9e83e1a040c0e21422f3d51125d : Validate MobileI2V Godot Project (43805059323), Verify Visual Backend API (43805059351), Validate KARMA ONE Godot scripts (43805059374), Verify 2D Storyboard Godot (43805059403) : SUCCESS. Le build Android historique 43805059322 est aussi SUCCESS ; son ancien intitulé V50 n'a pas été utilisé comme base.
- V54, commit 1276cebd00d6cad352319ad5dda2a301edafe8bf : Build Android APK KARMA ONE V54 (43821742737) et Verify 2D Storyboard Godot (43821742756) : SUCCESS. Ces anciens succès n'ont pas été présentés comme validation de toutes les modifications ultérieures.
- La comparaison GitHub a confirmé que la branche V54 est en avance sur V53.

## Livraison d'export déjà vérifiée
Commit : 11a6aff0080bc1e129f4360183f2fffa4462d87c.
Build SUCCESS : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43982302235
Archive : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43982302235/artifacts/14284475580

L'archive contient l'APK, SHA256SUMS.txt, les métadonnées Android et integration-proof/ :
- EXPORT_TEST_SIMULATED_DRAWINGS.mp4
- video_verification.json

APK : com.ericjamesempere.mobilei2v, versionCode 8, versionName 1.4.3 (Local V54), ARM64 uniquement.
Taille APK : 87 873 082 octets.
Signature APK v2 vérifiée.
SHA256 APK : e38b5901d03263daf960740d5f13abd9f511340801cad2950668fcbd2051091a.
Ce build précède les corrections de session Gradio décrites ci-dessous : ne pas le confondre avec leur compilation finale.

Le test du véritable écran et du véritable exporteur vérifie la chronologie exacte, le blocage avant accord, le refus, la correction ciblée, la conservation des voisins et la reprise sans accord global automatique. L'IA et MediaCodec sont remplacés par des fixtures ; ffmpeg encode réellement le fichier.

## Mesures du MP4 de test
| Contrôle | Résultat exécuté |
|---|---|
| Codec | H.264 |
| Format couleur | yuv420p |
| Résolution du fichier technique | 96 × 160 |
| FPS | 30/1 |
| Images | 150 |
| Durée | 5 secondes |
| Décodage de toutes les images | ffmpeg -v error -xerror : code 0 |
| Lecture dans Android/CapCut | NON exécutée |
| Dessins génératifs IA | NON : fixtures simulées |
| MediaCodec matériel Xiaomi | NON : remplacé par ffmpeg |

Ce MP4 est une preuve technique d'export, PAS une démonstration de qualité artistique, de fidélité des dessins ou d'animation universelle.

## Défaut réel isolé et corrections sur la branche
Les GET HTTPS, l'upload de la référence synthétique publique et la soumission de la tâche ont été exécutés avec succès. Le résultat Gradio était lu par un chemin ne correspondant pas à la session fournie ; le flux renvoyait « 404: Session not found. » avant une fermeture incomplète.
Preuve : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43983357462

La branche contient maintenant :
- 01da0719 : lecture de la file correspondant à la session et filtrage par identifiant de tâche.
- 52e0ae55 : lecture silencieuse des événements vides et capture du refus réel.
- 42377b65 : essai de modification du format d'entrée, ensuite retiré après vérification du prétraitement ModelScope : l'API exige bien FileData et effectue elle-même la conversion en chemins. Le format d'origine est conservé.

Dernier essai réel constaté sur 42377b65 :
https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43984127203
Réponse du fournisseur : process_completed, success:false, output:{error:null}.
Dessins produits : ZÉRO. Analyse sémantique : NON validée. Fidélité : NON validée.
La cause interne du refus n'est pas révélée ; aucun dépassement de quota n'est prouvé. Ne pas supprimer les contrôles pour obtenir un faux succès.
Compilation de ce correctif à consulter séparément :
https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43984127149
Son succès n'est pas présumé dans ce document.

## Recette physique préparée
Voir [RECETTE_XIAOMI_14T_PRO.md](RECETTE_XIAOMI_14T_PRO.md).
Aucun accès physique ou ADB au Xiaomi dans cette session. Galerie Android, interaction tactile, mémoire, MediaCodec matériel et lecture sur téléphone restent à exécuter.
MediaPipe n'a pas été exécuté et n'est pas déclaré validé.

## Limite de cette session
L'environnement local d'exécution est indisponible. Le fichier joint local et l'archive ZIP n'ont donc pas pu être ouverts ici ; leur lecture n'est pas affirmée. Le travail a utilisé les instructions du message, le code et les preuves consultables sur GitHub. Les compilations et contrôles décrits sont ceux effectivement constatés dans les workflows.

Statut : export technique vérifié et recette préparée ; finalisation universelle de bout en bout NON acquise.

## Livraison retenue après correction du transport — 17 novembre 2026

Commit applicatif compilé : 1063ff26a764de3bb8eff515d0e371fcb1d2dddc.
Tous les acquis V53/V54, le parcours idée seule, les projets, le contrôle individuel et les gardes de validation sont conservés.

La lecture des réponses vision utilise désormais la file de la session réellement soumise, avec filtrage de l'identifiant de tâche et refus des résultats d'un autre travail. Les événements vides ou malformés sont ignorés sans produire de faux résultat ni d'erreur de parseur dans les journaux. Les tests couvrent résultat exact, tâche étrangère, absence de résultat, erreur du fournisseur et sortie invalide.

Le passage temporaire à des chemins de fichiers a été retiré : le composant ModelScope attend FileData sur le réseau et effectue son propre prétraitement. Source vérifiée : https://github.com/modelscope/modelscope-studio/blob/main/backend/modelscope_studio/components/pro/multimodal_input/__init__.py
La correction conservée concerne la session et son flux de réponse ; elle ne remplace aucun moteur.

Build Android SUCCESS :
https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43984469732
Archive APK :
https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43984469732/artifacts/14284193252
SHA256 de l'APK :
44ca1f49b171ce079cd8b271464f81e55f60476decbff222d36aa69211618f6e

Résultats constatés dans ce build :
- HF_STUDIO_PROTOCOL_TESTS_OK.
- UNIVERSAL_IDEA_ENTRY_WIRING_OK : création initiale SIMULÉE, raccordement réel de l'écran.
- UNIVERSAL_ANDROID_INTEGRATION_OK : vision et MediaCodec SIMULÉS.
- MP4_EXPORT_VERIFIED : H264, yuv420p, 96x160, 30 FPS, 150 images, 5 secondes, décodage complet réussi avec ffmpeg.
- Compilation, signature et contrôles du paquet ARM64 réussis.
Les workflows Godot, storyboard et API de ce même commit sont réussis.

Essai réel après correction :
https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43984469671
Preuves conservées :
https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43984469671/artifacts/14284148070

La lecture de session récupère un message terminal process_completed correspondant à la demande ; il indique success:false et output:{error:null}. L'erreur de session masquée par la fermeture du flux est corrigée. La cause du refus restant n'est pas exposée par le service et n'est pas attribuée avec certitude au modèle, au quota ou à un paramètre précis. Aucune nouvelle génération de dessin n'a réussi : zéro PNG, zéro planche validée, aucune fidélité réelle confirmée.

Ne pas déclarer la finalisation universelle acquise. Prochaine étape utile : obtenir une analyse sémantique réelle réussie avec ce contrat ou un adaptateur réellement compatible, puis seulement tester les dessins et corriger les défauts visuels. Aucun appareil Xiaomi ni moteur local n'est accessible dans cette session.
