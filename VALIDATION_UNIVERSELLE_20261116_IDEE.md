# V54 — raccordement idée seule et essai réel, 16 novembre 2026

## Changements effectivement livrés

Code applicatif : c5a05702b6bfbaa40edd2059e31cf9c869125a08.
Commit compilé et testé : 16bfc38e623f6ba007df670cd24a466e95e7e2f9.

- Le bouton existant utilise l'histoire comme idée initiale si aucune image et aucune description séparée ne sont fournies.
- Une description initiale séparée reste prioritaire si elle est renseignée.
- La référence créée passe au même parcours universal_board_pipeline ; l'histoire complète est conservée.
- Une référence existante est réutilisée. Une erreur de création conserve le projet.
- Création de référence et génération sont bloquées pendant l'import d'une photo.
- L'écran propose désormais une image ou une idée ; il n'exige plus un héros humain.
- Aucun développement vidéo ni nouveau projet. Aucun moteur remplacé.

## Tests constatés

Build GitHub : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43971462328

Compilation Android ARM64 : SUCCESS.
Test test_friendly_studio : SUCCESS, incluant UNIVERSAL_IDEA_ENTRY_WIRING_OK.
Ce nouveau contrôle utilise une image SIMULÉE et vérifie le raccordement, la réutilisation de référence, la description facultative, la conservation sur échec et le blocage pendant import. Il ne mesure pas la qualité de l'IA.
Tests de protocole, transport local et intégration universelle : SUCCESS. L'IA est simulée dans ces suites ; le test d'intégration encode effectivement un MP4 avec ffmpeg, sans essai Xiaomi/MediaCodec matériel.

APK source : 16bfc38e623f6ba007df670cd24a466e95e7e2f9.
Archive : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43971462328/artifacts/14278344085
SHA256 de l'APK (pas de l'archive ZIP) :
60bc54fd1c939a74bd948b3830bcca8c6bda0aa07e3676c3b93b01572a9b9ae3

## Essai réel, sans modèle simulé

Workflow : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43971462258
Preuves : https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/43971462258/artifacts/14279195448
Script : tools/test_universal_live_board.gd.

Entrée : dessin synthétique déjà public validation/v54-poses/reference.png.
Histoire : la banane vivante se baisse puis se redresse, avec apparence, membres et fond conservés.
Chemin : véritable écran storyboard, mode distant, import réel du fichier, bouton de création, pipeline universel.

Résultat : ÉCHEC pendant la connexion au service d'analyse.
Message : « Analyse IA non aboutie ; tes dessins sont conservés. Service IA indisponible (HTTP 0, reseau 4). »
Nouveaux PNG générés : ZÉRO.
Fidélité vérifiée : NON.
Approbation humaine : NON.
Aucune image externe, procédurale ou simulée n'est présentée comme sortie de cet essai.

La cause exacte de connexion n'est pas établie : ce résultat ne permet pas de distinguer un problème réseau, d'environnement ou de disponibilité du fournisseur. Aucun quota GPU atteint n'a été constaté dans cet essai. Ne pas annoncer que le moteur de dessin lui-même a été exécuté.

## Limitations restantes et prochaine intervention utile

1. Diagnostiquer la connectivité HTTPS au service visuel depuis l'environnement réel, puis vérifier son contrat Gradio et un résultat d'analyse valide. Ne pas supprimer ce contrôle pour faire passer le test.
2. Obtenir de vrais dessins via ce parcours ; examiner identité, anatomie/géométrie, action, environnement, style et continuité ; corriger uniquement les dessins défectueux.
3. Tester des cas variés : humain, animal, objet/véhicule, scène à plusieurs sujets et transformation. Un seul cas ne certifie pas l'universalité.
4. Mesurer les pauses, mémoire et comportement d'import sur Xiaomi 14T Pro. Aucune garantie d'absence de ralentissement ou de plantage n'est acquise.
5. Pas d'essai physique Xiaomi dans cette intervention. Pas de qualité équivalente aux planches ChatGPT démontrée.
6. Les limites de service et les contraintes du calcul local restent réelles.

Le runtime local était indisponible. Les corrections ont été vérifiées par les workflows existants sur GitHub ; un workflow ciblé a exécuté un essai réel borné et conservé ses preuves d'échec. Le premier build c5a0570 a été annulé automatiquement par la politique de concurrence après le commit du test ; seul le build 16bfc38 ci-dessus est livré.

Statut : raccordement idée seule corrigé et testé ; objectif universel de qualité NON terminé.
