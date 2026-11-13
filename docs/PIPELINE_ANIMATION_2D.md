# Pipeline MobileI2V 2D — image, squelette et flux optique

Priorité : dessin animé 2D à partir d'une image choisie dans la galerie Android. La 3D est une option future.

## Étapes techniques
1. Importer toute image choisie par l'utilisateur via un sélecteur Android compatible content URI; la copier dans le stockage local du projet.
2. Détecter sujet, segmentation et articulations avec MediaPipe ou équivalent, en signalant les détections incertaines.
3. Créer les calques tête, torse, bras, jambes, décor; prévoir les zones cachées.
4. Transformer l'histoire en séquence chronologique de poses clés et prompts de mouvement.
5. Piloter le squelette 2D : longueurs de membres, appuis, centre de masse, accélérations et décélérations.
6. Produire une planche de poses avec le personnage original, prévisualisable et corrigeable.
7. Générer les images intermédiaires par déformation des calques; tester le flux optique pour lisser les transitions.
8. Gérer les occultations : le flux optique ne peut pas inventer les parties cachées ni une nouvelle vue complète.
9. Assembler les images en MP4 H.264 réel, avec message d'erreur si encodeur indisponible.

## Ordre de réalisation
P0 import photo Android et sauvegarde; P1 détection et planche; P2 animation squelette; P3 flux optique et qualité; P4 export MP4 et tests Xiaomi; P5 styles manga et personnages multiples; 3D ultérieure.

## Critères de validation
Image différente pour chaque projet; identité visuelle conservée; action « courir puis tomber » dans le bon ordre; aperçu planche et animation; MP4 lisible sur Android; aucune API payante obligatoire.

## Statut
Ceci est une spécification de développement, pas une implémentation ni un résultat de test. Préserver les fonctionnalités Godot existantes.