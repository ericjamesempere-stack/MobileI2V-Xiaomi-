# Livraison V2 : périmètre et preuves

Nom : KARMA_ONE_AUTOPILOT_V2_20261117. Nouvelle branche : karma/autopilot-v2-20261117. Aucune fusion dans main.

Les vérifications héritées par SHA figurent dans baseline_evidence.json. Le manifeste de source énumère les changements, leurs SHA256 et les références de départ. Le build versionné produit séparément la somme SHA256 du véritable APK, ses métadonnées ARM64 et sa vérification de signature. Le même build conserve les résultats de l'intégration et du MP4 technique.

| Fonction | Validation locale | Limite |
|---|---|---|
| Registre, graphe et outils du superviseur | PASS, 12 tests Python et exécution des 6 tâches raccordées | Exécuteurs déterministes, pas des LLM entraînés |
| Mémoire technique Android et budget | PASS, journal rejoué et troisième échec identique bloqué | Journal privé, aucun contenu de photo ni prompt |
| Planches avec poses et intermédiaires | PASS avec dessins synthétiques | Inférence réelle non prouvée |
| Garder / Refuser / Refaire / reprise | PASS avec écran de production et fixtures | Interaction tactile Xiaomi non testée |
| Validation obligatoire | PASS : incomplet, refusé, manquant, modifié ou non contrôlé bloquent | L'approbation réelle reste à l'utilisateur |
| MP4 technique | PASS : H264, 96×160, 30 FPS, 150 images, 5 s, décodage complet | Encodeur ffmpeg substitué, aucune preuve MediaCodec matériel |
| APK V2 | Consulter le résultat du build propre à ce commit | Un ancien APK V54 n'est pas l'APK V2 |
| Vision / dessins universels réels | BLOQUÉ : dernier fournisseur vision en refus non expliqué | Aucun modèle local chargé dans l'environnement |
| Galerie privée, lecture et export Xiaomi | NON TESTÉ sur appareil physique | Protocole : ../RECETTE_XIAOMI_14T_PRO.md |
| MediaPipe | NON TESTÉ | Aucun modèle exécuté |

Le lot de quatre intermédiaires par passe borne l'usage GPU. Un projet incomplet peut être repris avec les mêmes paramètres. Le cache conserve les dessins déjà générés et leurs contrôles valides ; la dernière confirmation humaine n'est pas automatiquement reconduite. La densité requise reste calculée selon l'action : le logiciel n'annonce pas un dessin animé complet après seulement quelques poses.

Pour une validation finale : exécuter un moteur réellement disponible, analyser et dessiner les cas humain/animal/objet/véhicule/créature/multi-sujets, examiner les planches, puis installer le nouvel APK sur Xiaomi et vérifier galerie, reprise, mémoire, encodage matériel et lecture. Aucun de ces résultats n'est inventé ici.
