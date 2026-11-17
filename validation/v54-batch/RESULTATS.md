# V54 — planches par lots, à partir de 46479e9

## Résultat réel

Le chemin de génération de l’application a produit une planche 1024×1024 en un appel Qwen Image Edit, puis quatre PNG 512×512 distincts. Scénario : « Une banane anthropomorphe court, trébuche et tombe. » Style cartoon ; quatre secondes prévues. Le sujet reste un fruit avec membres, sans torse humain générique. Les poses montrent une foulée, une position plus droite, un déséquilibre et une position couchée. La seconde pose ne démontre pas à elle seule une foulée opposée correcte. Le visage, la courbure et les proportions varient : fidélité stricte non certifiée.

L’inspection visuelle n’est pas une validation de l’utilisateur. Les quatre dessins sont sauvegardés avec human_approved=false et le montage attend cette validation. Aucun MP4 de ces dessins n’a été produit. Quatre images clés ne prouvent pas une animation fluide ni un moteur d’intervalles articulés.

Preuves : sheet_0000.png, frame_0000.png à frame_0003.png, karma_agents.json et app-real.log. Ce sont des pixels réellement générés par Qwen, pas un rendu procédural ni une déformation de la référence. La référence synthétique utilisée reste validation/v54-poses/reference.png.

## Causes et correction

- Qwen : l’essai précédent répondait quota GPU atteint après un dessin. L’application sollicitait le GPU séparément pour chaque dessin. La réservation GPU est gérée par le service distant, pas par l’APK. Le nouveau mode demande jusqu’à quatre poses dans une planche en un calcul et découpe les PNG sans agrandir artificiellement les sorties. La valeur initiale est quatre dessins. La réserve GPU restante n’est pas exposée par le service ; aucune disponibilité future ou création illimitée n’est annoncée.
- AnyPose : configuration accessible, upload accepté, deux entrées image valides et requête infer acceptée ; événement error/data:null sans dessin. La configuration du Space annonce show_error=false. L’échec n’est donc pas expliqué par la seule absence de la seconde image ; sa cause serveur précise reste inconnue, sans journaux serveur. L’APK ne peut pas réparer ce serveur tiers.
- Le client classe quotas, HTTP 429, authentification, transport et erreurs serveur masquées. Il tente l’autre adaptateur existant après un échec, puis ne répète plus le moteur en échec dans le même lot. Il s’arrête sur un refus de contenu et ne bascule pas pour contourner ce refus.
- Un moteur n’est marqué generated_unreviewed qu’après réception et décodage d’une image. Ce statut ne certifie ni les poses ni l’identité. Qwen a effectivement réussi ; AnyPose n’a pas de succès réel attesté. Le basculement réussi est testé avec simulation, pas annoncé comme deuxième service actuellement opérationnel. Les deux services utilisent Hugging Face : changer de Space ne garantit pas un quota GPU indépendant.
- Les images déjà présentes sont conservées. Les nouvelles planches brutes restent sur disque ; les projets partiels ne peuvent pas être exportés. Refaire conserve le calcul de pose existant et exige une nouvelle validation.

## Vérifications locales effectuées

Godot 4.6.3 : import sans erreur de script ; test_hf_studio_generator, test_remote_pose_briefs, test_hf_batch_fallback, test_reference_review_pipeline, test_hf_studio_ui et test_friendly_studio réussis. Le test de routage utilise des réponses simulées : Qwen quota → AnyPose réussi ; deux échecs → arrêt sans répétition ; refus de contenu → pas de basculement ; découpes exactes et refus des cellules trop petites.

Inférence réelle dans tools/test_v54_real_story.gd : quatre images obtenues, statut complete=true, aucun dessin approuvé. Après cet essai, test_hf_real_batch_cache réussit : quatre PNG réutilisés avec empreintes inchangées, zéro nouvelle inférence, validation humaine toujours absente. L’essai AnyPose réel échoue comme indiqué ci-dessus. Un appel exploratoire Qwen préalable avait aussi produit quatre poses ; seule la planche issue de l’application est livrée ici.

Les 12 contrats API et l’ancien FFmpeg n’ont pas été relancés localement : leurs composants sont inchangés. Le workflow Android existant vérifie les scripts modifiés, les contrôles de revue, la compilation, la signature et l’ABI. Son résultat doit être vérifié sur le commit livré.

## Android et livraison

Aucun téléphone, ADB ni émulateur accessible dans cette session. Aucun essai réel du sélecteur Android, d’une installation Xiaomi ou de MediaCodec matériel n’est annoncé. Version, versionCode, identifiant du paquet et branche V54 conservés. APK reconstruit à partir de ces corrections ; aucune V55.

La chaîne complète image → histoire → dessins → validation humaine → MP4 articulé reste non démontrée : les dessins sont désormais disponibles pour la validation, le second moteur reste indisponible, les intervalles fluides et le téléphone restent à vérifier. Le mode original utilise encore un adaptateur de style distant et ne garantit pas la reproduction exacte du style source.
