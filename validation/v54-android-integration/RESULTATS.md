# V54 — intégration du moteur universel dans le parcours Android

Base : 11caddf69d5f7d1d30990d11632c685f3fb02969, branche karma/v54-approval-safety-20261116. Modification du parcours existant, sans seconde interface ni reconstruction. Version Android incrémentée de 6 à 7, nom 1.4.2 (Integration V54), même identifiant de paquet et même mécanisme de signature.

## Raccordement réalisé

Le bouton existant « Créer mes dessins » appelle universal_board_pipeline.build_boards : analyse visuelle distante réelle, validation du registre, plan physique, génération, contrôle de fidélité et correction bornée. L'ancien générateur de ce bouton a été retiré. L'analyse est sauvegardée avant le contrôle du budget ; un budget insuffisant n'entraîne aucun calcul de dessins. Aucune heuristique ou annotation de test n'est utilisée en remplacement d'une analyse indisponible.

Les PNG obtenus alimentent les aperçus et la planche existants. Le registre, la qualité, le style, la signature de la demande, la chronologie et le journal de session sont conservés à la sauvegarde/reprise. Les générations partielles restent examinables mais ne sont pas exportables.

« Refaire » réutilise repair_keypose avec le dessin cible et le registre du projet ; les voisins restent inchangés et seul le dessin modifié est réexaminé. Les anciens projets importés V53/V54 conservent leur examen et leur reprise ; les nouvelles créations passent toutes par le moteur universel.

La confirmation exige toujours Garder sur chaque dessin, aucune pose refusée, une planche complète et, pour un projet universel, une analyse et une fidélité confirmées. La référence, les paramètres, les empreintes des PNG et les liens de leurs examens doivent toujours correspondre. Changer l'histoire, la durée, le style ou les images bloque la réutilisation de l'accord. Une reprise ne rétablit jamais la confirmation globale automatiquement.

L'export natif existant reçoit la chronologie à 30 images/seconde construite à partir des video_frame du plan. Il maintient les poses entières sans fondu. Ce sont des poses clés maintenues : cette intégration ne produit pas les dessins intermédiaires manquants et ne prouve pas une animation fluide.

Le service visuel Gradio reçoit maintenant un session_hash persistant pour ses composants à état ; les images envoyées pour l'analyse sont bornées à 1024 pixels de grand côté, sans modifier la référence sauvegardée. La soumission en ligne n'a lieu qu'après le bouton de création, dont le texte explique l'envoi pour analyse, dessin et contrôle. Un simple import ne déclenche aucun envoi.

## Vérifications locales

Godot 4.6.3. Test d'intégration du véritable écran storyboard et du véritable moteur : import → parseur d'analyse → registre/plan → PNG → planche → Garder/Refuser/Refaire → confirmation → export. Les réponses IA et le transport MediaCodec sont simulés. Le véritable code d'export est exécuté ; ffmpeg encode réellement les images reçues et ffprobe confirme 150 images, durée 5 secondes. Les empreintes des 150 images reçues sont comparées aux poses de la chronologie exacte.

Cas vérifiés : export impossible avant accord ou après refus ; correction d'un seul fichier et un seul réexamen ; empreintes des voisins identiques ; reprise sans restauration de l'accord global ; modification d'histoire ; analyse indisponible sans substitution ; budget insuffisant sans génération ; génération partielle ; contrôle de fidélité indisponible. Ces derniers cas bloquent l'export.

Les régressions touchées passent : reference_review_pipeline, friendly_studio, hf_studio_ui, detailed_style_reference et disk_drawing_sequence. Aucun relancement local des anciennes suites de rendu/procédural inchangées.

Le nouveau test d'intégration est raccordé aux workflows Build Android APK KARMA ONE V54 et Verify 2D Storyboard Godot. Les résultats distants doivent être constatés sur le commit publié, ils ne sont pas présumés ici.

## Essai distant et limites

Un essai réel est parti du bouton de l'écran, avec uniquement la banane synthétique déjà publique dans validation/v54-poses/reference.png. La visibilité publique du dépôt et l'accès HTTP anonyme au fichier ont été vérifiés ; blob Git exact : 2829bd752b8a17d1ebf42041663e487aae0930f0. Aucune photo personnelle n'a été utilisée.

Le premier essai a été interrompu par le contrôle automatique d'autorisation. Après vérification de la provenance publique, un nouvel essai a été autorisé. Il a échoué pendant l'appel au fournisseur visuel : HTTP 0, résultat réseau Godot 4. L'écran conserve la référence, ne déclare pas d'analyse sémantique et ne lance pas les dessins. Aucun succès d'analyse réelle ni de fidélité réelle n'est affirmé. La fermeture immédiate du script diagnostique a aussi signalé un objet libéré pendant l'émission d'un signal ; cette fermeture utilisait free(), alors que le parcours de l'application utilise queue_free().

La chaîne logicielle est donc raccordée et testée avec substituts ; la disponibilité du fournisseur et la qualité universelle des images restent non confirmées en conditions réelles.

Sur Xiaomi 14T Pro restent à vérifier : mise à jour de l'APK, ouverture, sélection et affichage de photo via le sélecteur natif, accès réseau au fournisseur, fidélité visuelle, consommation mémoire, Garder/Refuser/Refaire sur écran tactile, encodage matériel MediaCodec et partage du MP4. Les tests Robolectric et Godot de CI ne remplacent pas ces essais.
