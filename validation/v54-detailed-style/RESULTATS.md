# V54 — référence de style et dessins plus détaillés

Base : 045c97d55dd52cb006106bff4b054ecf1a4ef09e. Branche, versionCode et versionName conservés. Aucune reconstruction de l’application.

## Corrections ciblées

- Ajout du mode BD détaillée, sans couleurs plates imposées. Les six anciens indices de style sont conservés ; le nouveau choix se sauvegarde et se restaure.
- Import facultatif d’une référence de style avec le sélecteur existant, aperçu, retrait et copie privée. Cette référence guide le trait, les ombres et les matériaux ; elle ne remplace pas le sujet. L’annulation remet correctement la cible d’import à zéro.
- Les images transmises à Qwen ont des rôles explicites : sujet, style, puis contexte temporel. Le composant Style-Transfer déjà exposé par le service est réutilisé. Le mode Original ne force plus Anything2Real. Refaire utilise la même référence de style et reste soumis à une nouvelle validation.
- Pour BD détaillée ou une référence de style : deux panneaux portrait de 512×1024 par calcul au lieu de quatre cases de 512×512. Pas d’agrandissement des sorties pour simuler une définition supérieure. Les styles rapides restent sur quatre cases. Le cache distingue la référence de style et la nouvelle politique de génération.
- Limite d’import Android/Godot relevée à 4096 pixels de grand côté pour préserver davantage de détails du fichier de départ. Les copies envoyées au modèle sont bornées à 1024 pixels, conformément à la limite effective de ce service. Ce changement ne transforme pas sa sortie en véritable 4K.
- AnyPose ne reçoit pas silencieusement une demande de style qu’il ne prend pas en charge dans ce parcours. En cas de quota ou d’échec, les dessins existants restent conservés ; aucun dessin simplifié n’est présenté comme équivalent.

## Essai réel dans l’application

Une pose a été recadrée localement dans la planche fournie par l’utilisateur pour servir de sujet. La planche complète a été importée séparément comme référence de style. Le recadrage du sujet était une préparation de l’essai, pas une fonction de détection automatique de planche ajoutée à l’application.

Chemin exécuté : import image → import référence de style → BD détaillée → histoire → _draw_remote_story. Deux dessins demandés, en un appel Qwen, histoire « Il danse, puis s’accroupit et pointe vers la camera. » Résultat : deux PNG 512×1024 enregistrés, complete=true, human_approved=false. actual_inference.json consigne les dimensions et l’état du moteur.

Inspection visuelle : cheveux, visage, plis du vêtement, mains, chaussures, contours et ombres nettement travaillés ; décor et design global proches de la référence. La première pose reste accroupie et ne réalise pas correctement la danse demandée. La seconde montre un geste de pointage vers la caméra. La fidélité exacte du visage, le cadrage intégral et la conformité universelle des actions ne sont pas certifiés. Une planche complète de seize poses n’a pas été testée dans cet essai.

Les références et les images du personnage fourni ne sont pas publiées dans le dépôt ; les sorties sont livrées dans la conversation. Aucun nouvel export vidéo n’a été autorisé pour ces deux dessins.

## Contrôles

Godot 4.6.3 : import sans erreur de script ; test_detailed_style_reference, test_hf_studio_generator, test_hf_batch_fallback, test_reference_review_pipeline, test_hf_studio_ui et test_friendly_studio réussis. Le nouveau test vérifie les rôles distincts des images, la conservation du sujet à l’import d’un style, annulation/retrait/reprise, le choix BD détaillée, la résolution d’import et les découpes portrait sans agrandissement.

Tests Android Robolectric adaptés : conservation d’une image 3200×1600 et borne d’une image 8192×1024 vers 4096×512, en plus du test existant d’import URI. Ils sont exécutés par le workflow APK ; leur succès doit être constaté sur le commit livré. Ce sont des tests simulés Android, pas un essai Xiaomi.

Aucun téléphone ou émulateur disponible. Installation, sélecteur système et encodage MediaCodec matériel non testés. Les contrats API Python et l’encodage MP4 restent inchangés et n’ont pas été relancés localement. La conformité de tous les mouvements et l’animation fluide demeurent des limites distinctes de cette amélioration de détail.
