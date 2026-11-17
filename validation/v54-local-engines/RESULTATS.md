# V54 locale — connexion aux moteurs Android existants

Base vérifiée : 8a703997f914384f5cc66549db2ab0fc079bb7ce. Version Android 1.4.3 (Local V54), versionCode 8. Même branche, identifiant de paquet, signature et parcours de planches. Aucun moteur natif MNN ni poids de modèle n'est embarqué dans cette APK.

## Fonctionnalités implémentées

Le mode local du véritable écran utilise universal_board_pipeline, les mêmes registres, calculs de poses, caches, contrôles et validations. Il remplace uniquement le transport d'inférence : MNN Chat (vision, API OpenAI compatible sur 127.0.0.1:8080) et Local Dream (txt2img/img2img, API sur 127.0.0.1:8081). La création du personnage, la création de planches et Refaire utilisent ce choix. Le mode en ligne existant reste disponible ; aucune bascule en ligne automatique n'a été ajoutée au mode local.

Les applications de calcul doivent être installées et leurs modèles chargés séparément sur le téléphone. L'interface l'indique et fournit les liens officiels. Il ne s'agit donc pas encore d'une application unique autonome prête sans installation complémentaire. Aucun test sur Xiaomi ne lève cette limite dans cette étape.

- Analyse locale de l'image et de l'histoire, sélection du modèle courant annoncé par MNN Chat, envoi d'images inline base64. Le parseur et le validateur de scène existants restent obligatoires ; une erreur n'est jamais remplacée par une fausse analyse.
- Génération locale d'un dessin à la fois. Source PNG préservée, copie d'entrée centrée dans un carré sans étirement. Décodage strict du format final Local Dream : RGB brut encodé en base64, dimensions et longueur vérifiées. Un résultat intermédiaire ou incomplet n'est pas un dessin terminé.
- CPU demandé par défaut (use_opencl=false). Aucun chemin Qualcomm NPU n'est supposé compatible avec le MediaTek. La documentation Local Dream signale des sorties GPU incorrectes sur certains MediaTek.
- Refaire conserve l'historique et les fichiers voisins. La référence de style séparée est explicitement refusée par cet adaptateur à entrée unique ; elle n'est pas ignorée silencieusement.
- Le nombre de poses du mode local est calculé par le plan, sans le plafond par lot des appels cloud. Cela ne supprime pas les limites physiques de durée, stockage, mémoire ou température.
- Seules des miniatures de 320 pixels maximum sont conservées pour la planche stricte. L'examen agrandi et le MP4 lisent les PNG complets sur disque, sans perte volontaire de définition dans l'export.
- Les connexions de cet adaptateur sont exclusivement 127.0.0.1 avec un port explicite. Les proxies de développement sont ignorés. Un jeton local MNN peut être saisi ; il ne figure pas dans la sauvegarde. Le réseau Android autorise le HTTP en clair uniquement pour 127.0.0.1, les services distants restent en HTTPS.
- Le choix local est sauvegardé. Les anciens projets universels distants conservent leur mode pour ne pas changer leurs liens de contrôle ; les anciennes références sans plan strict passent au choix local par défaut.

## Tests exécutés

Godot 4.6.3 : test_local_studio_transport.py pilote les véritables écrans, pipeline, clients HTTP et décodeur de pixels, contre un serveur de test sur boucle locale. Les réponses des deux modèles sont SIMULÉES. Compteurs : 1 inventaire des modèles, 1 analyse, 9 examens de dessins et 10 générations (1 sujet, 8 poses, 1 correction). Aucun appel cloud, aucun téléchargement de modèle et aucune inférence réelle ne sont effectués par ce test.

Le test couvre aussi : 8 poses produites malgré une limite cloud réglée à 2, proxy invalide ignoré, PNG source non étiré, sortie RGB tronquée refusée, adresses non locales refusées, source complète à l'examen, correction d'un seul fichier, conservation des voisins, confirmation obligatoire, reprise du choix et de la planche, absence du jeton dans la sauvegarde.

Régressions réussies après le changement de transports et de miniatures : universal_android_integration (MP4 ffmpeg réel, 150 images/5s ; IA/MediaCodec simulés), universal_board_contract, universal_review_resume, hf_studio_generator, reference_review_pipeline, friendly_studio, hf_studio_ui, detailed_style_reference. L'export du test compare désormais les pixels attendus des PNG originaux, pas ceux des miniatures.

Les deux workflows Godot et APK exécutent le test de transport local. Le workflow APK contrôle également la présence de la configuration réseau locale dans le paquet final. Leurs résultats doivent être constatés sur le commit publié avant livraison.

## Configuration requise sur le Xiaomi

1. Installer MNN Chat depuis les releases officielles alibaba/MNN. Télécharger un modèle réellement multimodal compatible avec les images, le charger et activer son API sur 127.0.0.1:8080. Recopier son jeton dans KARMA ONE si l'authentification est activée. Le port et l'adresse doivent correspondre ; ne pas ouvrir l'API sur le réseau public.
2. Installer Local Dream depuis les releases officielles xororz/local-dream. Choisir un paquet SD1.5 CPU possédant aussi un encodeur VAE pour img2img, télécharger les poids et charger le modèle. Le service écoute sur 127.0.0.1:8081 seulement lorsque le modèle est chargé. Conserver le mode CPU au départ.
3. Garder les moteurs disponibles en arrière-plan ; les restrictions batterie de HyperOS peuvent arrêter leurs services. Cette exigence d'exploitation n'est pas levée par la compilation.
4. Dans KARMA ONE, activer le mode local, importer une image, décrire une action courte, créer et inspecter les dessins. La validation de fidélité et la confirmation humaine restent nécessaires avant MP4.

## Ce qui n'est pas démontré

Pas d'installation de ces moteurs sur le Xiaomi, pas de mesure de leur RAM simultanée ou de temps de calcul, pas de première image réellement générée par cette combinaison, pas de fidélité universelle, pas de contrôle matériel MediaCodec dans cette étape. Le contrôle de fidélité peut refuser les images si les modèles ne réalisent pas correctement le mouvement. Les dessins intermédiaires manquants du moteur universel ne sont pas produits par ce connecteur ; l'export conserve les poses clés sans fondu.

Cette livraison est un raccordement local testable, PAS la preuve d'une application complète universelle fonctionnant sur le Xiaomi du début à la fin. Les quotas de service ne s'appliquent pas aux calculs locaux ; le temps de calcul, le stockage et la chauffe restent nécessaires.

## Sources des contrats

- https://github.com/alibaba/MNN/blob/master/apps/Android/MnnLlmChat/app/src/main/java/com/alibaba/mnnllm/api/openai/network/models/OpenAIChatRequestModels.kt
- https://github.com/alibaba/MNN/blob/master/apps/Android/MnnLlmChat/app/src/main/java/com/alibaba/mnnllm/api/openai/network/services/MNNModelsService.kt
- https://github.com/alibaba/MNN/blob/master/apps/Android/MnnLlmChat/app/src/main/java/com/alibaba/mnnllm/api/openai/network/processors/MnnImageProcessor.kt
- https://ld.chino.icu/features/http-api
- https://ld.chino.icu/compatibility
- https://ld.chino.icu/known-issues
