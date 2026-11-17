# V54 : corrections ciblées des consignes de pose

Base inchangée : d0da158072e66d00bc2b41ebafd439023440c2ee. Branche V54 conservée ; V53 est un ancêtre de cette base.

Corrections : au moins un dessin par action ; états physiques explicites pour course/trébuchement/chute ; retrait de l’histoire complète de chaque requête pour éviter de dessiner toutes les actions à la fois ; même plan de pose pour Générer et Refaire, y compris sur une planche partielle ; Refaire demande une nouvelle graine ; le dessin précédent est un contexte non approuvé, pas un deuxième personnage. Le cache est versionné pour conserver les anciennes images sans réutiliser leurs anciennes consignes.

## Tests exécutés le 16 novembre 2026

- Godot 4.6.3 : import et analyse des scripts, sans erreur de script.
- test_remote_pose_briefs : réussi. Ordre course/course/trébuche/trébuche/chute/chute ; au moins une image par action ; refus d’un compte trop petit ; consigne conservée au remplacement.
- test_hf_studio_generator : réussi. Protocole simulé, référence conservée et nouvelle graine seulement pour Refaire.
- test_reference_review_pipeline : réussi. Import, reprise, validation, refus, planche partielle et verrou export.
- test_hf_studio_ui : réussi. Référence exacte, sauvegarde et absence de jeton dans le projet.
- Les 12 tests API et l’encodage FFmpeg antérieurs portent sur du code inchangé : résultats V54 antérieurs conservés, pas de relance locale.

## Inférence réelle par le chemin de l’application

Commande : KARMA_TEST_REFERENCE=<reference.png synthétique> godot --headless --path . --script res://tools/test_v54_real_story.gd.
Scénario : Une banane anthropomorphe court, trébuche et tombe. Six dessins demandés, quatre secondes, style cartoon.

Résultat : 1/6 dessin réellement obtenu de Qwen Image Edit, PNG 1024×1024. Inspection visuelle : nouvelle pose de course d’un fruit avec membres, sans torse humain générique. Couleurs et style ont évolué ; la fidélité stricte et la continuité entre plusieurs dessins ne sont pas prouvées. Le deuxième appel a échoué : quota GPU gratuit atteint. Le premier PNG et le projet partiel sont conservés. Aucun export n’a été approuvé ni vidéo créée pour cette séquence incomplète.

Les fichiers reference.png, frame_0000.png et app-inference.log sont les preuves effectives, pas des images simulant une séquence. L’erreur de destruction à la fin du journal provient du script de test qui libérait la planche pendant l’émission du signal HTTP ; le script utilise désormais queue_free et attend une frame avant de quitter. L’inférence n’a pas été relancée pour cette correction de nettoyage.

AnyPose, déjà présent comme adaptateur optionnel : configuration et upload HTTP 200, requête acceptée HTTP 200, puis événement error/null sans dessin. Il n’est pas activé comme basculement. Aucun deuxième moteur gratuit de redessin n’est validé disponible. Le backend Python diffusion/I2V nécessite modèles, dépendances et calcul GPU absents de l’APK ; ce n’est pas un moteur Android local utilisable.

## Blocages non résolus

- Quota du moteur gratuit : impossible de vérifier six poses successives dans cet essai.
- Analyse sémantique universelle et cohérence temporelle non validées ; les mesures locales sont des mesures de pixels, pas un modèle de vision.
- Le service LoRA impose un adaptateur de style, dont Anything2Real pour le mode original : fidélité au style original non garantie. Aucune configuration sans adaptateur n’est exposée par cet endpoint.
- Aucun appareil Android réel accessible : galerie Xiaomi, installation et MediaCodec matériel non testés.
- Aucune nouvelle démonstration MP4 : ne pas confondre l’ancienne vidéo procédurale avec une animation IA de ces dessins.

Version APK demandée : ARM64, code 6, nom 1.4.1 (Poses V54). La compilation et les vérifications de signature/ABI sont assurées par le workflow existant après ces tests ciblés. Sa réussite doit être vérifiée sur le commit livré ; ce document ne l’anticipe pas.

La mission de génération universelle n’est pas déclarée terminée.
