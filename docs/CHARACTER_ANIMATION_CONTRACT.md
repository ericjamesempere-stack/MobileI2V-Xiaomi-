# MobileI2V — Cahier des charges global : studio d'animation à la demande

## Vision produit (prioritaire)
Application Android gratuite sur Xiaomi 14T Pro permettant de créer **n'importe quelle histoire animée** en style manga, BD ou dessin animé. L'utilisateur écrit librement ce qu'il souhaite, peut fournir une ou plusieurs images de départ (facultatives), puis lance la génération. **Ne pas limiter l'application aux visages, humains ou squelettes.**

## Sujets possibles
Personnes, animaux, véhicules, objets, lieux, paysages, architectures, personnages imaginaires et mélanges de plusieurs sujets. Une image peut servir de référence pour le sujet, l'objet, le décor ou le style, pas uniquement pour une tête.

## Parcours utilisateur
1. Image(s) facultative(s) + histoire/prompt libre + style manga/BD/cartoon + durée.
2. Analyse du récit : personnages, objets, lieux, actions, interactions, chronologie, intentions.
3. Création automatique d'un storyboard : scènes, plans, poses-clés, mouvements de caméra, décor et continuité.
4. Création d'une fiche de référence par entité (apparence, couleurs, vêtements, forme, proportions, état) et d'un état de scène (positions, relations, temps, décor).
5. Génération d'images clés originales, puis d'images intermédiaires réellement distinctes et cohérentes.
6. Assemblage de petites séquences animées de type GIF, enchaînées sans rupture visible ni incohérence narrative. Dernière image et état de la scène N transmis à la scène N+1.
7. Export GIF ou MP4, aperçu, sauvegarde, reprise et correction sélective des scènes ratées.

## Critères de réussite non négociables
- Aucune tête photographique collée dans un cercle sur un corps générique.
- Pas de simple zoom, déformation ondulante ou déplacement d'image fixe présenté comme une animation.
- Mouvement réel des sujets, y compris gestes, roues, objets, transformations et déplacements dans l'espace.
- Visages expressifs lorsqu'un visage existe; ne pas inventer de visage pour un objet si non demandé.
- Préservation des caractéristiques de toute image de référence et de l'identité des entités entre les scènes.
- Cohérence des actions et de la causalité de l'histoire.
- La création d'un sujet nouveau à partir d'une image arbitraire exige un véritable modèle génératif ou un workflow d'édition d'images; un rig 2D fixe n'y suffit pas.
- Indiquer explicitement les fonctions encore indisponibles, quotas des moteurs externes et échecs de génération.

## Première démonstration d'acceptation
15 secondes, plusieurs scènes enchaînées, image de référence facultative, un objet animé et un personnage ou décor; cohérence visuelle et export MP4 vérifié. Tester aussi le cas sans image.

## État technique actuel (ne pas confondre avec le produit final)
Le dépôt contient un moteur procédural 2D pour un avatar humanoïde et un générateur de PNG. Il ne possède pas encore de générateur généraliste d'images, de fiche d'entités universelle, de moteur de continuité multi-scènes ni de pipeline MP4 Android validé. La vidéo MP4 de démonstration produite séparément ne valide pas ces fonctions dans l'application.

## Priorités d'implémentation
1. Compilation/test Godot existant.
2. Modèle de projet: entités de tout type, images de référence, scènes, état et transitions.
3. Planificateur narratif et storyboard universels.
4. Interface de génération/édition avec sélection du style.
5. Adaptateur de moteurs d'image/animation autorisés, mode local clairement identifié, gestion des erreurs et quotas.
6. Continuité, interpolations, rendu et export MP4/GIF.
7. Tests sur appareil réel et validation des critères.

Ne jamais revenir à une conception limitée à « photo de visage + avatar générique ».
