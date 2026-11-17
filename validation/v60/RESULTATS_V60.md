# KARMA ONE V60 — finalisation Android simplifiée

Base vérifiée avant modification : f040951cd249be63c310246c882bd2260fe67ef4, branche karma/v60-simplified-assisted-20261117. La base V60 masquait des réglages, mais conservait les anciens noms d'étapes, n'incluait pas la réception ACTION_SEND et n'avait pas encore les identifiants V60. La documentation V59 absente de sa branche est restaurée. Tous les modules précédents sont conservés.

## Changements fonctionnels

1. Créer : photo ou idée et histoire sur la même page, styles conservés, bouton Préparer et ouvrir ChatGPT. Une idée seule remplit la consigne si aucune action séparée n'a été saisie.
2. Mes dessins : import, réception, grille 4×2 par défaut et correction manuelle masquée jusqu'au besoin, agrandissement Garder/Refuser/Refaire, remplacement ciblé. Les imports externes ouvrent cette étape de revue.
3. Ma vidéo : lecture des poses, confirmation humaine obligatoire, MP4 natif enregistré dans Movies/KARMA ONE, lecture par le lecteur Android et partage. La dernière URI vidéo est conservée pour lecture/partage après réouverture ; un fichier déplacé/supprimé peut nécessiter une nouvelle sélection dans la galerie.

Les moteurs configurés et leurs actions sont dans les réglages avancés, fermés par défaut. Aucune fonctionnalité de génération précédente n'est supprimée. Le parcours reste dans storyboard.gd, chatgpt_board_bridge.gd et les contrôles/export existants.

## Réception native d'image

L'application apparaît comme cible Android ACTION_SEND, type image/*. Elle valide action, type et URI content:// ; un fichier privé file://, une URL réseau, un texte ou un envoi multiple ne sont pas importés par ce récepteur. Les données sont réellement décodées par ReferenceImageImporter hors thread UI, bornées à 4096 pixels et copiées dans un PNG privé avant retour à KARMA ONE. Les autorisations temporaires du partage restent portées par l'activité pendant la copie ; aucune autorisation globale de galerie n'est ajoutée.

Une boîte privée persistante reçoit une seule image à la fois, sans modifier de projet. L'écran affiche un aperçu et demande : image de départ, planche ou dessin refait. La cible de remplacement doit correspondre à la demande en attente ; les voisins et les fichiers d'origine restent conservés. Le bouton Ignorer libère l'attente ; Plus tard la conserve. Une réception interrompue ne peut pas bloquer définitivement les suivantes. Un deuxième partage est refusé tant qu'une image attend une décision.

Le partage de l'IMAGE dans ChatGPT doit fournir une URI d'image. Si ChatGPT partage seulement un lien de conversation ou n'affiche pas KARMA ONE, enregistrer l'image puis utiliser la galerie/Importer la planche. Aucun faux accès automatique à Plus, API illimitée ou contournement de quota n'est ajouté.

## Tests et preuve attendue

- Godot 4.5.2 : tests ciblés réussis localement pour les trois pages, paramètres masqués, idée sans photo, confirmation de l'image reçue, import/sauvegarde/reprise, grille, Garder/Refuser/Refaire, remplacement ciblé et blocage d'export. Le transport de partage Android est simulé dans ces tests d'écran.
- Régressions liées : import V58, pont V59, revue de référence, navigation, styles, sauvegarde, intégration jusqu'au MP4 : réussies localement. Le véritable MP4 de test d'intégration utilise FFmpeg et des dessins de fixture ; il ne certifie pas une inférence IA ou MediaCodec matériel.
- Tests Java ajoutés : validation des intents, résultats persistants, doublons, interruption, et réception ACTION_SEND → vrai décodage PNG → vrai fichier privé via le framework Robolectric. Ce dernier simule Android, pas les octets de l'image. Il ne constitue pas un essai physique du Xiaomi.
- La compilation et ces tests Java sont constatés dans le workflow du commit final. Aucun résultat de compilation n'est présumé par ce document.

## Animation

Aucune transition expérimentale n'est ajoutée. La lecture de huit poses reste une lecture de poses maintenues. Les dessins intermédiaires réels des moteurs existants sont conservés lorsqu'ils sont disponibles ; zooms, fondus et déformations ne sont pas présentés comme des dessins génératifs. Le renforcement de la fluidité ne bloque pas cette livraison.

## Installation et validation Xiaomi

APK souhaité : KARMA_ONE_V60_SIMPLIFIED_ANDROID_ARM64.apk. Version 1.6.0 (V60 Simplified), code 15, paquet com.ericjamesempere.mobilei2v. Publication sur la branche existante V55 pour réutiliser la signature V59/V58/V57 de référence, avec contrôle du certificat 5fe844e7ae98d51d5464f1e3a7d58e218aeade4c11b8fe4a1c5ed5e45d9663ef.

Installer par-dessus V59 sans désinstaller. En cas de refus de signature, conserver l'installation et ses données ; ne pas forcer leur suppression.

Test rapide : photo JPG puis PNG → aperçu → fermer/réouvrir → idée sans photo → préparer ChatGPT → générer dans ChatGPT → partager l'image vers KARMA ONE → choisir Planche → inspecter les cases → Refuser/Refaire un dessin → importer son remplacement → vérifier les voisins → Garder chaque dessin → confirmer → exporter, lire et partager le MP4. Tester aussi Ignorer, Plus tard et deux partages successifs.

Aucun accès au Xiaomi/ADB physique n'est disponible ici. Sélecteur de ce téléphone, partage réel ChatGPT/Android 16, lecture/encodage MediaCodec et maintien des accès URI sur HyperOS restent à vérifier sur l'appareil. Les tests automatisés ne sont pas déclarés comme une validation Xiaomi.

Source Android utilisée pour le contrat de réception : https://developer.android.com/develop/ui/compose/sharing/receive .
