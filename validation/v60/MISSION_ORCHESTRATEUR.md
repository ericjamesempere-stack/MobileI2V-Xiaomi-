# KARMA ONE V60 — mission de l'orchestrateur

## Base immuable
- Dépôt : ericjamesempere-stack/MobileI2V-Xiaomi-
- Branche : karma/v60-simplified-assisted-20261117
- Base V60 : f040951cd249be63c310246c882bd2260fe67ef4
- Préserver les projets, les acquis V53–V59, le package com.ericjamesempere.mobilei2v, les contrôles de validation et l'export MP4.
- Ne jamais substituer un ancien APK renommé. Ne jamais déclarer un test sur Xiaomi sans test physique.

## Orchestration, dans cet ordre
1. **Agent inventaire** : repérer les véritables modules d'orchestration/agents et workflows présents ; comparer V59/V60 ; ne pas inventer de fichiers.
2. **Agent UX** : vérifier le code modifié dans scripts/studio_friendly_ui.gd ; corriger toute erreur Godot ; garder 3 étapes simples et options avancées repliées. Attention aux références UI et aux callbacks existants.
3. **Agent Android** : auditer les intents de partage entrants ACTION_SEND image/*, content URI et permissions ; implémenter si possible la réception sécurisée de planches ChatGPT dans le parcours existant, sans automatisation non officielle de ChatGPT. Préserver l'import galerie V58.
4. **Agent storyboard** : vérifier split_board, sauvegarde atomique, validation humaine, Refaire ciblé et refus des résultats périmés. Ne pas annoncer de fluidité professionnelle pour une vidéo de poses maintenues.
5. **Agent tests** : exécuter tests ciblés Godot/Java/Robolectric et test export/décodage MP4. Corriger les erreurs réellement observées. Vérifier la version Android 1.6.0 / versionCode 15 sans collision.
6. **Agent build** : déclencher le workflow GitHub Actions adapté à la branche ; si workflow_dispatch indisponible, préparer un déclencheur autorisé et expliquer le blocage. Vérifier signature compatible V59, ARM64, manifeste, taille, SHA256.
7. **Agent livraison** : publier lien GitHub Actions vers l'artefact exact et rapport validation/v60/LIVRAISON_V60.md, avec SHA256 calculé sur les octets de l'APK. Signaler explicitement les tests Xiaomi non réalisés.

## Critères d'acceptation
- Photo/texte -> partage ChatGPT assisté -> retour/import -> planche -> Garder/Refuser/Refaire -> validation -> MP4.
- Aucune perte de projets, aucun faux moteur Plus automatique, aucun quota prétendument illimité.
- Pas de livraison sans artefact téléchargeable et preuve de build.
- Le SHA256 cc38026e499de5666a13092fbe4a2ee6c5bb5d17af9905f63cc20746ea18856e est une empreinte fournie par l'utilisateur, **non attribuée à un APK** : ne la considérer comme validée qu'après comparaison avec le fichier réel.

## Compte rendu attendu
Tableau agent / fichier modifié / tests / preuve / blocage. Commit final, workflow run, artifact ID, signature et SHA256. En cas d'impossibilité d'exécution, ne pas prétendre avoir orchestré des agents externes.
