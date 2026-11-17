# KARMA ONE V58 — correctif candidat, 17 novembre 2026

Base : 8176fb4dd6aeafa8f07d3a63ffdc47f61677187c, confirmée aux deux branches V57 avant modification. Version Android : code 13, 1.5.8 (V58 Android). Aucun modèle embarqué ajouté. Aucun fichier/photo personnelle publié. La version V57 et ses acquis sont conservés dans l'historique.

## Bug A : import Android

Constats de code : le résultat V57 ne vivait que dans l'instance Java du plugin, sans boîte persistante. L'interface ne distinguait pas attente du retour Android et décodage. Le délai générique ne prouve pas laquelle de ces étapes a échoué sur le Xiaomi. La cause précise sur cet appareil n'est pas confirmée sans son journal. Godot 4.5.2 transmet effectivement Activity → GodotFragment → Godot → onMainActivityResult ; le callback existe dans cette version.

Correctif : une activité Android interne, non exportée, reçoit directement le résultat du sélecteur, sans dépendre du cycle de vie du plugin Godot. Le résultat et son rôle (sujet/style) sont conservés dans une boîte privée persistante. Recréation Godot, annulation et résultats tardifs sont gérés ; un résultat annulé ne peut pas remplacer un nouvel import. Un arrêt du processus pendant le décodage est signalé, pas présenté comme un succès. Lecture URI avec autorisation temporaire, prise d'autorisation persistante lorsqu'elle est accordée, libération après copie. Décodage et compression hors thread UI, limite 4096 px, PNG privé unique. JPG/PNG/WebP/HEIC dépendent du décodeur Android réellement installé ; aucun support HEIC n'est revendiqué sans essai matériel.

L'écran récupère le résultat même après recréation, affiche sélection/décodage/sauvegarde et nomme l'étape si le délai expire. Les anciens projets disposent d'un manifeste project.json en plus de leurs images. Aucun dessin précédent n'est effacé par un nouvel import. Mes images enregistrées reprend le manifeste du projet choisi, plutôt que de réinitialiser son histoire et ses dessins. Les gardes Garder/Refuser/Refaire et export restent en place.

Tests réellement passés localement : écran Godot 4.5.2 et 4.6.3, import d'un WebP réel, pixels/aperçu, sauvegarde, réouverture, récupération d'un résultat avec état UI réinitialisé, erreur, annulation, imports successifs et conservation des manifests. C'est un test du véritable écran et des fichiers, PAS du sélecteur Android. Les tests Java Robolectric sont des simulations du framework, PAS des essais sur Xiaomi.

## Bug B : moteur absent/non joignable

V57 contient des connecteurs, pas les moteurs MNN Chat/Local Dream ni leurs modèles. HTTP 0 signifie absence de réponse HTTP ; il ne prouve ni installation ni compatibilité. Les adresses 127.0.0.1 désignent le téléphone au moment de l'exécution Android, pas cet environnement de développement.

Le choix local/distant est désormais disponible dès la première étape, avant la création texte → image. Il était sur la page Histoire, après l’entrée initiale, ce qui rendait le secours distant difficile à sélectionner. Aucun envoi automatique ajouté.

Ajouts : rapport natif des paquets Local Dream et MNN Chat (standard/release) visibles via queries limitées ; diagnostic des requêtes avec endpoint, code HTTP et résultat réseau ; libellé explicite installation/modèles requis. Les contrôles /health et /v1/models ne sont jamais assimilés à une inférence réussie. Aucun envoi en ligne automatique ajouté.

Essai réel du connecteur distant existant : demande texte uniquement « A single yellow banana on a blue table, curved fruit body, no human limbs ». API joignable et contrat compatible ; l'inférence est REFUSÉE : ZeroGPU quota exceeded, authentification HF demandée. Voir live_text_result.json. Aucun dessin réel reçu. Ne pas relancer en boucle, ne pas contourner le quota. Le mode distant doit être choisi explicitement dans l'interface avant tout transfert de photo privée.

Blocage externe précis : aucun téléphone/ADB connecté, aucune preuve d'installation ou de modèle actif sur Xiaomi ; le service distant gratuit essayé refuse l'inférence pour quota. Il faut un moteur réel disponible pour démontrer image, planche fidèle puis vidéo IA. Rien de cela n'est simulé pour valider artificiellement la livraison.

## Compilation et signature

La branche de correction est karma/v58-android-real-fixes-20261117. Publication par avance rapide de karma/v55-finalisation-20261117 pour réutiliser la clé V55/V57 mise en cache. Le workflow exige le certificat SHA256 5fe844e7ae98d51d5464f1e3a7d58e218aeade4c11b8fe4a1c5ed5e45d9663ef. Ne pas livrer un APK signé d'une nouvelle clé. Un APK compilé est un candidat, pas la preuve des niveaux C et E.

La compilation Java locale est bloquée par la résolution du plugin Gradle Android 8.5.2. Le workflow GitHub réalise la compilation native et les tests dans son environnement Android. Son résultat doit être lu avant toute annonce de succès.

## État des validations

- A : contrôles Godot ciblés passés ; compilation/tests natifs à constater dans GitHub.
- B : fichiers/écran/reprise testés localement ; sélection content:// et affichage Android non validés matériellement.
- C : tentative réelle distante refusée pour quota ; aucune inférence réussie revendiquée.
- D : le test d'intégration existant produit un vrai MP4 FFmpeg à partir de dessins de fixture ; il ne démontre ni IA réelle ni MediaCodec matériel.
- E : aucun accès physique/ADB au Xiaomi, donc non validé.

## Installation et test très simple

1. Installer uniquement l'APK V58 dont la signature a passé le workflow, par-dessus la V57 publiée avec la clé V55. Ne pas désinstaller l'application contenant les projets.
2. Si Android refuse la mise à jour, conserver l'installation et relever le message. Les anciennes V56/candidats V57 peuvent avoir une autre signature ; ne pas forcer une désinstallation.
3. Galerie → choisir un JPG local → constater aperçu + dimensions. Fermer/réouvrir KARMA ONE et vérifier la référence. Répéter avec PNG/WebP puis HEIC si disponible. Tester annuler, revenir, tourner l'appareil et choisir une deuxième photo ; consulter Mes images enregistrées pour retrouver la première.
4. Vérifier les moteurs du téléphone, puis copier le diagnostic. Il doit préciser application installée, connexion et modèle annoncé ; cela ne garantit pas l'inférence. Télécharger/charger les moteurs et modèles ne peut pas être fait à distance sans accès au téléphone.
5. Seulement avec un moteur réel opérationnel : décrire une banane sur une table, créer son image puis « elle tombe et finit couchée ». Examiner chaque dessin, refuser/refaire une pose, conserver ses voisins et confirmer avant MP4. Lire le MP4 dans la galerie.
6. En mode distant, le choix implique transfert d'image/histoire aux services annoncés ; quotas et disponibilité variables, aucun abonnement automatique, aucune promesse d'illimité.

Sources primaires vérifiées : code Godot tag 4.5.2-stable (GodotActivity.kt, GodotFragment.java, Godot.kt) ; https://ld.chino.icu/features/http-api ; manifests/build.gradle officiels alibaba/MNN et xororz/local-dream.
