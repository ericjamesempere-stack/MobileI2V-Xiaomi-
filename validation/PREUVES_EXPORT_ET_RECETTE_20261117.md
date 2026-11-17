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
- 42377b65 : format du composant multimodal Qwen adapté aux chemins de fichiers attendus.

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
