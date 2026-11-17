# KARMA ONE V60 — APK livré et vérifié

## Identification

- Branche vérifiée : `karma/v60-simplified-assisted-20261117`.
- Base demandée conservée : `f040951cd249be63c310246c882bd2260fe67ef4`.
- Commit applicatif compilé : `e2e433b9d4248e808017df8b6cd856775dcb6a5c`.
- Version : **1.6.0 (V60 Simplified), code 15, ARM64**.
- Paquet inchangé : `com.ericjamesempere.mobilei2v`.
- APK : `KARMA_ONE_V60_SIMPLIFIED_ANDROID_ARM64.apk`.
- Taille : **87 987 774 octets**.
- SHA256 : `6e5dc905682c2b5a5bc6c54e26b8f5c27e9d050d19571525515c0470f2ed9ebc`.
- Certificat SHA256 : `5fe844e7ae98d51d5464f1e3a7d58e218aeade4c11b8fe4a1c5ed5e45d9663ef`, **identique à V59 de référence**.
- [Workflow réussi](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44194752593).
- [Artefact GitHub exact](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44194752593/artifacts/14379151180).

Une seule compilation a été lancée pour ce lot V60. La publication utilise la branche V55 existante pour retrouver sa clé de signature ; les deux branches pointaient vers le même code testé. Le présent rapport est ajouté après compilation et ne change pas l'APK.

## Ce qui change

**Créer** regroupe photo, idée, histoire et style, puis prépare le prompt et ouvre le partage vers ChatGPT. **Mes dessins** regroupe import, grille 4×2 par défaut, correction manuelle et Garder/Refuser/Refaire. **Ma vidéo** conserve la confirmation humaine, l'export MP4 et le partage, avec un bouton de lecture Android. Les moteurs et commandes techniques restent dans les options avancées.

KARMA ONE reçoit désormais les images envoyées par le partage Android. Une copie PNG privée est décodée en arrière-plan avant retour dans l'application. L'utilisateur choisit référence, planche ou remplacement ciblé ; la réception seule ne change pas le projet. Les requêtes périmées et les remplacements visant un dessin modifié sont refusés. Ignorer libère l'image reçue, Plus tard la conserve. Une seule image partagée peut attendre une décision à la fois.

Aucune fonctionnalité antérieure n'a été supprimée. Les projets, anciens moteurs, registres, commandes de revue et exports sont conservés. Aucune interpolation expérimentale, déformation ou fausse animation IA n'est ajoutée : une séquence de poses reste présentée comme telle.

## Tests constatés

| Contrôle | Résultat | Nature de la preuve |
|---|---|---|
| Scripts, démarrage et parcours Godot 4.5.2 | Réussis | Exécution réelle du code, pas téléphone |
| Trois étapes, idée seule, import, grille, revue, remplacement ciblé, conservation des voisins et reprise | Réussis | Écran de production ; transport Android simulé |
| 11 tests Java du plugin | Réussis | Robolectric simule Android ; un test reçoit un vrai PNG via un fournisseur content et vérifie le fichier privé réellement décodé |
| Validation obligatoire avant export | Réussie | Tests des gardes, clics simulés dans les projets de test |
| MP4 d'intégration | H.264, 96×160, 30 FPS, 150 images, 5 s, décodage complet sans erreur | FFmpeg réel ; dessins et MediaCodec de fixture |
| APK | Signature, version 15, paquet, ARM64, manifeste et classes natives vérifiés | Véritable APK ; SHA256 vérifié aussi après téléchargement |
| Xiaomi 14T Pro physique | Non effectué | Aucun accès au téléphone/ADB |

Les tests Java ne démontrent pas le comportement physique de ChatGPT/HyperOS. Aucune nouvelle inférence IA n'était nécessaire pour cette correction d'interface et d'intégration. L'exemple réel V59 reste conservé ; il ne prouve pas une animation fluide ou une fidélité universelle.

## Installer et utiliser sur Xiaomi

1. Télécharger l'APK et l'installer **par-dessus V59 de référence, sans désinstaller**. Si Android refuse la signature, conserver l'installation et les projets ; ne pas forcer leur suppression.
2. Dans Créer, choisir une photo JPG/PNG ou écrire une idée/histoire, puis Préparer et ouvrir ChatGPT. L'utilisateur lance la génération dans ChatGPT.
3. Dans ChatGPT, ouvrir l'image générée puis **Partager l'image → KARMA ONE**. Choisir Planche dans KARMA ONE. Si seul un lien de conversation est partagé, enregistrer l'image et utiliser Importer la planche, ou la partager depuis la galerie.
4. Vérifier la grille et chaque dessin. Garder / Refuser / Refaire ; pour un dessin refait, importer seulement son remplacement demandé.
5. Dans Ma vidéo, confirmer les dessins puis créer le MP4. Il est enregistré dans **Movies/KARMA ONE** ; Lire ma dernière vidéo et Partager ma vidéo utilisent le lecteur et le partage Android.

Le mode ChatGPT reste assisté et soumis aux limites du compte. Aucun accès automatique inventé à Plus, aucune clé API gratuite illimitée et aucun contournement de quota ne sont utilisés.

## Vérifications restantes sur le téléphone

Sélection JPG/PNG, retour d'activité, réception effective d'une image depuis ChatGPT, autorisations temporaires sur HyperOS, affichage après fermeture/réouverture, encodage MediaCodec, lecture et partage du MP4. Tester également Ignorer, Plus tard et deux partages successifs. Ces points ne sont pas déclarés réussis sur Xiaomi sans essai physique.

[Détail des correctifs et du protocole](RESULTATS_V60.md).
