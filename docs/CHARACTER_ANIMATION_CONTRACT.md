# MobileI2V — Contrat de génération de personnages animés

## Objectif non négociable
Une photo et une histoire doivent produire automatiquement une animation MP4 avec un personnage reconnaissable. Le rendu doit être une vraie succession de dessins cohérents, pas une photo ondulée ou zoomée.

## Styles
- Manga
- Bande dessinée / comic
- Dessin animé 2D

## Invariants visuels
- Le **corps entier** doit reprendre la silhouette, les vêtements, les cheveux et les proportions de la référence.
- Le visage doit être intégré au dessin du personnage, **jamais une photo collée dans un rond**.
- Les traits du visage doivent varier réellement : yeux ouverts/fermés, sourire, bouche ouverte, surprise, grimace.
- Les membres doivent bouger selon des poses anatomiquement cohérentes : course, chute, saut, danse.
- La continuité du personnage et de ses vêtements est obligatoire d'une image à la suivante.
- Une simple déformation de l'image source n'est pas une animation acceptable.

## Pipeline cible
1. Importer photo(s) et consigne libre.
2. Détecter ou annoter les caractéristiques du personnage et préparer une fiche de référence (model sheet) corps entier, face/profil, expressions.
3. Convertir le texte en actions et en storyboard avec poses-clés et cadrages.
4. Générer les images clés avec identité et style constants.
5. Produire des dessins intermédiaires cohérents entre les poses (interpolation du rig + redessin ou moteur génératif autorisé).
6. Contrôler visuellement identité, expressions, mouvement et continuité; régénérer les images ratées.
7. Encoder et vérifier le MP4 sur Android, sauvegarder et reprendre le projet.

## Test d'acceptation initial
- Vidéo verticale de 15 secondes : courir, tomber, sauter, danser.
- Le personnage complet ressemble à la référence; visage dessiné expressif et non figé.
- Gestes réellement distincts image par image, transitions crédibles.
- MP4 lisible, durée vérifiée, aucune substitution silencieuse par une animation d'image fixe.

## État actuel / limites
Le rendu procédural 2D du dépôt ne garantit ni identité complète ni expressions faciales. Le MP4 de démonstration produit hors application ne prouve pas que le moteur Android fonctionne. Ne pas déclarer le projet terminé sans validation réelle.

## Règle de développement
Préserver ces exigences pendant chaque correction; ne pas remplacer le pipeline par un avatar générique, une tête circulaire ou un simple effet de zoom.
