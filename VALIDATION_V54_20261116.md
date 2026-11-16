# KARMA ONE V54 — corrections et limites vérifiées, 16 novembre 2026

Base : `1276cebd00d6cad352319ad5dda2a301edafe8bf`, branche `karma/v54-approval-safety-20261116`. Aucune reconstruction du projet, aucune photo privée utilisée.

## Corrections

- Les exports AVI, PNG et le transfert à l'ancien lecteur demandent désormais la même validation humaine complète que le MP4.
- Un dessin décoché, refusé, modifié ou manquant bloque la validation. Une génération distante partielle reste sauvegardée, mais ne peut pas être validée comme un film complet.
- « Tout retirer » persiste après réouverture ; les refus sont réindexés correctement si un fichier manque ; le style personnalisé est conservé.
- Le backend diffusion optionnel n'impose plus visage, cheveux et vêtements à un fruit ou un objet.
- Les workflows Godot et contrat API couvrent désormais la branche V54.
- Version Android portée à code 5, nom 1.4 pour distinguer cette mise à jour.

## Vérifications locales exécutées

Godot officiel 4.5.2 : import, validate_karma_one, test_reference_review_pipeline, test_hf_studio_generator, test_hf_studio_ui et test_friendly_studio réussis. Le test de revue couvre import/prévisualisation/reprise, agrandissement, refus, refus d'une planche partielle, invalidation après modification et blocage des anciens exports.

Python : 12 tests `test_visual_backend_contract.py` réussis. Ils utilisent des modèles simulés et ne prouvent ni MediaPipe ni la qualité d'un modèle diffusion. Les erreurs ERR_FILE_CORRUPT du validateur correspondent au fichier volontairement corrompu de son test de récupération.

## Preuves GitHub de la base

- APK V54 : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43821742737
- Storyboard : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43821749561
- Contrôles Godot/API antérieurs sur V53 : runs 43805059374 et 43805059351, SHA `769614a5913ba9e83e1a040c0e21422f3d51125d`. Ce ne sont pas des validations V54.

APK de base téléchargé et inspecté : 80 346 325 octets ; SHA256 `e3cf3ceaa230577575c0b754bec21afcedd8179cacd3111585803a4b9ff419eb` ; seule ABI arm64-v8a ; classes MP4Exporter et ReferenceImageImporter, méthodes de sélection et de partage présentes. Aucun fichier modèle ONNX/TFLite/MediaPipe/Safetensors intégré. Ce checksum ne désigne PAS l'APK recompilé après les présentes corrections.

## Inférence réelle effectuée (hors contrats simulés)

Les configurations publiques des deux services utilisés par `hf_studio_generator.gd` ont répondu. Un appel Z-Image-Turbo a créé une banane 1024 × 1024, puis Qwen Image Edit a effectivement produit un nouveau PNG 1024 × 1024 avec le protocole de l'application. L'inspection visuelle du redessin montre une duplication partielle du fruit et une chute non conforme. Conclusion : génération distante réelle accessible lors du test, mais fidélité de l'action NON validée. Ce test ne prouve pas une animation fluide.

## Limites qui restent

- Pas d'appareil Android, d'ADB ni d'émulateur accessible ici : installation/lancement Xiaomi, véritable sélecteur de galerie et encodage MediaCodec sur téléphone restent à tester. Les tests Robolectric du build sont simulés.
- Aucun moteur génératif local ni MediaPipe exécuté dans cette session. Le backend Python optionnel requiert modèles et dépendances externes.
- Les moteurs distants gratuits ont des quotas et leur disponibilité n'est pas garantie. Aucun basculement automatique vers un second moteur de redessin compatible n'est actuellement raccordé. Lore Motion/WAN/LTX/Kling/Vidu ne sont pas intégrés par le simple fait de les nommer.
- L'analyse de référence mesure dimensions/couleurs/visibilité ; ce n'est pas une compréhension sémantique universelle de l'image. Le scénario est découpé par des règles déterministes.
- Le MP4 de planche conserve les dessins successifs. Quelques images clés maintenues à 30 fps ne constituent pas une animation fluide avec nouveaux dessins intermédiaires. Le rendu articulé local est une démonstration 2D, pas du redessin IA fidèle à une photo.
- Une vidéo vérifiée par FFmpeg sur ordinateur ne valide pas MediaCodec sur Xiaomi.

L'application n'est donc pas déclarée terminée au sens du cahier des charges « studio universel autonome ».
