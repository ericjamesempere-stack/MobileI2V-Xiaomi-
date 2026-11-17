# KARMA ONE V59 — livraison du mode ChatGPT assisté

17 novembre 2026, France. Solution construite pour utiliser la génération normale de ChatGPT sans dépendre de Hugging Face ZeroGPU. **Mode assisté : l'utilisateur lance la génération dans ChatGPT et importe son résultat dans KARMA ONE.** Ce n'est pas une connexion API automatique au générateur d'images de Plus.

## APK vérifié

- Source compilée et testée : `3a71ae4fe16b8d63c9f001278021dda92b10251f`.
- Version : 1.5.9 (V59 ChatGPT assisté), code 14, même paquet `com.ericjamesempere.mobilei2v`.
- APK ARM64 : `KARMA_ONE_V59_CHATGPT_ASSISTED_20261117_ARM64.apk`.
- Taille : 87 961 496 octets.
- SHA256 : `5997c30c4a191f31472344394be8c8df4365fe5d2c3356b50cb98a68ca390535`.
- Certificat SHA256 : `5fe844e7ae98d51d5464f1e3a7d58e218aeade4c11b8fe4a1c5ed5e45d9663ef`, identique aux V57/V58 de référence.
- [Compilation et contrôles réussis](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44190672790).
- [Artefact exact](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44190672790/artifacts/14376806661), expiration 17 décembre 2026.
- Le présent rapport ne modifie pas le code de l'APK testé.

## Résultats constatés

- Compilation Java/AAR et 7 tests Robolectric réussis, dont protection du fournisseur de partage contre les chemins privés/arbitraires.
- Test du nouveau pont ChatGPT et suite Godot 4.5.2 réussis : import V58, découpe, revue, reprise, remplacement ciblé, résultats périmés, validation obligatoire, export intégré et démarrage.
- Paquet ARM64, signature, classes natives, fournisseur de partage et manifeste présents, contrôlés dans le véritable APK.
- Image réellement générée ici par l'outil d'images de ChatGPT : huit poses d'une banane dansant, sautant, tombant puis se redressant. Aucun humain ni membre humain imposé à la banane.
- Véritable écran KARMA ONE utilisé pour découper cette image et sauvegarder les huit dessins. Aucun dessin gardé automatiquement à l'import ; clics de validation simulés uniquement dans le projet isolé de test.
- Vrai MP4 FFmpeg à partir de ces dessins IA : H.264, 444×444, 30 FPS, 180 images, 6 secondes, décodage complet sans erreur. SHA256 vidéo : `5443448634030e27180bd3cf6074e612351fa6ea48c2a223e0ea5729aaa6ae33`.
- Ce film lit huit poses maintenues. Aucune génération de dessins intermédiaires supplémentaires ni fluidité professionnelle revendiquée.

## Installation et usage simples

1. Installer cet APK **par-dessus V58 ou la V57 de référence, sans désinstaller**. En cas de refus de signature, conserver l'ancienne installation et ses projets.
2. Importer une référence ou écrire une idée. Pour une image initiale, utiliser Créer cette image dans ChatGPT, puis importer l'image enregistrée avec Choisir une photo.
3. Dans Histoire, décrire l'action puis Envoyer l'histoire à ChatGPT. Le partage transmet la référence principale et la consigne à l'application choisie. Si le texte n'est pas repris, il est déjà copié : le coller dans ChatGPT.
4. Dans ChatGPT, lancer la génération et enregistrer l'image originale sur le téléphone.
5. Revenir dans KARMA ONE et Importer la planche de ChatGPT. Grille demandée : 4 colonnes × 2 lignes ; ajuster les champs si l'image réellement reçue a une autre grille.
6. Inspecter chaque découpe et chaque action. Garder / Refuser / Refaire. Pour Refaire, générer la pose demandée dans ChatGPT puis Importer le dessin refait ; seuls sa cible et son état de validation changent, les voisins restent conservés.
7. Confirmer la planche puis exporter le MP4.

Le mode ne demande ni clé API payante, ni mot de passe ChatGPT dans KARMA ONE, ni installation Local Dream/MNN. Il ne déclenche aucun appel ZeroGPU. Les limites du compte ChatGPT restent applicables et l'utilisateur garde l'action de génération dans ChatGPT. Le partage natif joint la référence principale ; une référence de style distincte doit être ajoutée manuellement dans ChatGPT.

## Limites exactes

L'accès officiel au forfait Plus pour applications personnelles existe pour des requêtes éligibles, mais exclut actuellement la génération d'images dans ce flux. C'est pourquoi cette livraison passe par l'application ChatGPT et n'affiche pas un faux moteur Plus connecté. Sources : https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations et https://learn.chatgpt.com/docs/sign-in-with-chatgpt .

Le partage entre les applications Android, la prise en compte du texte/de la photo par ChatGPT et l'encodage/lecture MediaCodec sur le Xiaomi ne sont pas validés physiquement ici : aucun accès au téléphone. Le mode dispose d'un secours explicite par consigne copiée et pièce jointe manuelle. La vraie génération d'exemple a eu lieu dans cette conversation, pas dans l'APK.

L'import ne certifie ni la provenance IA de chaque fichier, ni la fidélité visuelle universelle. La planche régulière et les poses restent à examiner humainement. Le mode autonome local/distant antérieur est conservé, avec ses dépendances et ses limites.

[Correctifs et protocole détaillés](RESULTATS_V59.md).
