# KARMA ONE V59 — création avec ChatGPT, sans dépendre de ZeroGPU

Base : V58 testée 457ec74, rapport 223708d. Même application Android, mêmes projets, même import natif et mêmes commandes d'inspection/export. Version Android 1.5.9 (V59 ChatGPT assisté), code 14. Aucun moteur précédent n'est supprimé.

## Solution effectivement construite

Mode **assisté**, pas une API automatique : KARMA ONE prépare la demande, copie le prompt et partage la référence privée avec l'application ChatGPT choisie par l'utilisateur. L'utilisateur lance la génération dans ChatGPT avec son compte habituel, enregistre l'image puis importe le résultat depuis le sélecteur Android existant. La demande peut aussi partir d'une idée, sans photo.

- Étape Image : Créer cette image dans ChatGPT, puis Choisir une photo pour importer son résultat.
- Étape Histoire : Envoyer l'histoire à ChatGPT puis Importer la planche de ChatGPT. Consigne standard 4 colonnes × 2 lignes, ajustable à l'import si le générateur ne respecte pas la grille.
- La découpe ne déforme pas les dessins. Cases petites, vides, uniformes ou strictement identiques refusées. Une grille régulière n'est pas certifiée automatiquement ; l'inspection humaine reste nécessaire.
- Planche envoyée au même écran Garder / Refuser / Refaire et au même export. Aucun dessin importé n'est automatiquement gardé. Aucun zoom ou fondu n'est présenté comme un dessin génératif.
- Pour une planche de ce mode, Refaire prépare une demande ChatGPT pour un seul dessin ; Importer le dessin refait ne remplace que sa cible. Son ancien fichier et les voisins sont conservés. Les changements de projet, consigne ou fichier ciblé bloquent les imports périmés.
- La provenance est déclarée par l'utilisateur ; l'import ne prétend pas vérifier quelle IA a produit l'image ni sa fidélité.
- La référence de style séparée, si souhaitée, doit être ajoutée manuellement dans ChatGPT ; le partage natif envoie seulement la référence principale.

## Pourquoi cette solution, et ce que Plus permet

Documentation officielle vérifiée le 17 novembre 2026 : Sign in with ChatGPT peut autoriser des requêtes Responses avec le forfait d'un utilisateur Plus éligible, mais le flux en préversion EXCLUT la génération d'images. Il serait trompeur de présenter une connexion OAuth Plus comme un moteur d'images disponible dans KARMA ONE.

Le mode construit utilise donc l'application ChatGPT pour sa génération d'images normale. Il n'utilise ni endpoint privé ChatGPT, ni cookie récupéré, ni connexion automatisée, ni clé API payante. Il n'appelle pas Hugging Face/ZeroGPU ni Local Dream/MNN pour ce parcours. Il ne supprime pas les limites de l'abonnement ChatGPT et ne contourne aucun quota. L'utilisateur reste responsable de l'action Générer dans ChatGPT.

Sources :
- https://developers.openai.com/siwc/token-sharing-open-source
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- https://learn.chatgpt.com/docs/sign-in-with-chatgpt

## Confidentialité du partage Android

Le partage est déclenché uniquement par le bouton explicite. Le fournisseur de fichiers n'est pas exporté, n'autorise que la lecture et n'expose que des copies PNG de partage portant un UUID. Les projets privés ne sont pas exposés comme un répertoire navigable. Les autorisations URI sont temporaires. Le mot de passe ChatGPT et les jetons du compte ne sont jamais demandés par KARMA ONE. Si ChatGPT ne reprend pas le texte du partage, la consigne est déjà dans le presse-papiers et peut être collée.

## Preuves réalisées

1. Tests Godot 4.5.2 : vrai écran, découpe, erreurs, doublons, sauvegarde/reprise, remplacement ciblé, refus des résultats périmés, blocage avant validation ; art synthétique de fixture pour ces tests de code. Régressions V58 et examens existants réussis localement. Tests Java du fournisseur et compilation sont contrôlés par le workflow du commit publié ; leur résultat doit être constaté.
2. VRAIE génération d'image par l'outil d'images de ChatGPT dans cette conversation : planche de huit poses d'une banane vivante dansant, sautant, tombant puis se redressant. Pas d'inférence exécutée dans l'APK. Pas de photo personnelle utilisée.
3. Le véritable importeur de l'écran KARMA ONE a découpé cette planche et sauvegardé ses huit dessins ; ils étaient tous non validés à l'import. Clics de validation simulés dans un projet de test isolé pour exercer la garde d'export, pas validation automatique d'un projet utilisateur.
4. Vrai MP4 FFmpeg à partir de ces dessins IA : H.264, 444×444, 30 FPS, 180 images, 6 secondes, décodage complet sans erreur. Huit poses maintenues, aucun mouvement intermédiaire inventé. Encodage MediaCodec matériel non testé sur téléphone.
5. La séquence montre des états différents et une morphologie de banane conservée, avec une cohérence visuelle raisonnable sur cet exemple. Cela ne démontre pas une fidélité universelle, la conservation d'un visage personnel, ni une animation professionnelle fluide.

L'image originale générée est conservée avec la conversation. Son SHA256 est 27cd85a9ff01d5b87423bd078dece0a1604166146afe63b7b5d679b7d9d46fdd. Le script tools/v59_import_real_sheet.gd reproduit l'import avec KARMA_REAL_SHEET et KARMA_REAL_PROOF. Les caractéristiques vidéo sont dans real_video.json, l'import dans real_import.log.

## Installation et utilisation

Installer l'APK V59 par-dessus la V58/V57 de référence, sans désinstaller. La compilation de publication réutilise le certificat V55/V57/V58 et exige son empreinte. Ne pas forcer une installation si Android refuse une signature ; conserver les projets.

1. Importer une référence ou décrire une idée.
2. Dans Histoire, écrire l'action puis Envoyer l'histoire à ChatGPT. Cela ouvre le partage ; choisir ChatGPT si un sélecteur apparaît.
3. Dans ChatGPT, vérifier la référence et le prompt, puis demander la génération. Enregistrer l'image originale sur le téléphone.
4. Revenir dans KARMA ONE, Importer la planche de ChatGPT, vérifier 4 colonnes et 2 lignes ou ajuster la grille réelle.
5. Agrandir chaque case. Garder / Refuser / Refaire selon le résultat. Après Refaire dans ChatGPT, utiliser Importer le dessin refait.
6. Confirmer la planche, puis exporter le MP4.

## Limites restant à valider

Pas d'accès physique/ADB au Xiaomi : ouverture de l'application ChatGPT par l'intent de partage, réception du texte et de l'image, sélecteur Android et MediaCodec restent à tester matériellement. La compilation et Robolectric ne sont pas assimilés à cette validation. Si le partage du texte n'est pas repris, coller la consigne copiée et joindre la référence manuellement.

Ce mode supprime le blocage ZeroGPU pour la création dans ChatGPT, avec une intervention humaine entre les applications. Il ne transforme pas KARMA ONE en moteur autonome de génération d'images couvert par Plus.
