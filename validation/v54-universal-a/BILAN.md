# V54 — générateur de planches : progression et échec du test A

Base initiale vérifiée : 3ae0812e8d436cee54badadba83783f57033d840. Travail ensuite rebasé sur 359269f8317a4386dafdf7e3d3e1d6771290d2d3, dernier état distant vérifié de la branche V54 ; correctifs photo, danse, séquences et cadrage préservés. Modifications limitées au moteur de planches, à ses tests et à ses preuves. Aucun travail d’interface, d’APK ou de MP4. La mention [skip ci] du commit évite de déclencher les compilations et contrôles non concernés.

## 1. Analyse de l’image et provenance

Référence : validation/v54-poses/reference.png, dessin synthétique déjà public dans le dépôt, blob Git 2829bd752b8a17d1ebf42041663e487aae0930f0. L’empreinte des pixels lie le registre à cette source. L’inventaire ci-dessous est une **annotation visuelle de l’assistant**, pas une reconnaissance automatique exécutée dans l’application. Les positions et caractéristiques du mouvement sont des estimations.

| Identifiant du projet | Élément observé | Invariants | Évolution autorisée |
|---|---|---|---|
| e1 | Banane jaune courbe, contour et tige bruns, yeux noirs, sourire, deux bras et deux jambes filaires existants | Identité, silhouette, couleurs, nombre de membres ; aucun torse humain ajouté | Articulations, orientation et déplacement requis par l’action |
| e2 | Ligne de sol horizontale | Sol plat et fixe, sans ajout d’accessoire | Contacts avec le personnage |
| e3 | Fond beige uni | Couleur, éclairage et point de vue fixes | Aucun changement demandé |

scene.json conserve les identifiants, boîtes approximatives, attributs, relations, origine et changements autorisés. Le validateur refuse les rôles non résolus, les IDs dupliqués, les coordonnées incohérentes et les références à une autre image. Il ne transforme jamais une mesure de pixels en reconnaissance sémantique.

L’interface officielle Qwen3-VL a accepté l’upload public et la requête (HTTP 200), puis renvoyé event:error/data:null avec un fichier FileData correctement envoyé. Aucun inventaire de modèle n’a été obtenu. La cause serveur n’est pas exposée ; ni une exécution réussie du modèle, ni une cause précise de panne ne sont affirmées. vision_probe.json et les deux flux SSE conservent ce constat. Pas de nouvelle recherche de modèles après cet échec.

Le premier transfert a été refusé par le contrôle automatique d’autorisation, qui considérait l’image comme privée. Le dépôt public et le blob identique ont ensuite été vérifiés ; les essais suivants ont référencé ou téléchargé uniquement ce dessin public. Aucune photo privée n’a été envoyée au nouveau service visuel. Le nouveau client exige un accord explicite pour les autres images.

## 2. Décomposition et calcul des dessins

Histoire : « Le personnage court, trébuche puis tombe. » Durée demandée : 5 secondes, vidéo prévue à 30 FPS. Le registre est annoté ; les nombres ci-dessous sont une prévision explicable, **pas une densité minimale prouvée perceptuellement**.

| Action | Durée calculée | Phases clés | Intermédiaires estimés | Images vidéo |
|---|---:|---:|---:|---:|
| Course : appui gauche, suspension, appui droit | 2,500 s | 3 | 23 | 75 |
| Trébuchement : pied bloqué, perte d’appui | 0,933 s | 2 | 10 | 28 |
| Chute : descente, impact, repos au sol | 1,567 s | 3 | 18 | 47 |
| Total | 5,000 s | **8** | **51** | **150** |

Les durées sont réparties en unités vidéo entières, selon les poids estimés des actions, avec assez d’unités pour chaque phase. Les poses respectent ce minimum physique. La densité d’intermédiaires tient compte de la vitesse, de l’amplitude, des interactions, des occlusions, de la caméra, du nombre d’acteurs mobiles et de la fluidité cible. Les caractéristiques et coefficients sont enregistrés dans plan.json. Un segment statique utilise une pose tenue ; une action complexe augmente la densité. Les actions simultanées se décrivent dans un même groupe avec tous leurs acteurs et phases communes.

**51 intermédiaires restent à produire : zéro n’a été généré ni interpolé.** Aucun rig adapté à la référence ni correspondance géométrique n’est vérifié. Le moteur ne considère donc pas ces 150 images vidéo comme 150 dessins IA, et ne fabrique pas de déformation pour combler les manques.

## 3. Génération réelle et défauts

Qwen Image Edit a effectivement produit huit PNG candidats, conservés avec leurs empreintes, les deux planches brutes et les métadonnées de contrôle technique. Il s’agit d’un essai diagnostique avec l’annotation ci-dessus, pas d’un succès du pipeline automatique complet. TEST_A_PLANCHE_CANDIDATE.png présente les huit candidats dans l’ordre.

L’inspection de l’assistant constate :

- Poses 1 et 3 : attitudes de course, mais contact précis au sol incertain.
- Poses 2 et 4 : ajout d’un objet au sol non demandé ; le trébuchement devient un contact avec cet accessoire.
- Pose 5 : la perte d’équilibre demandée n’est pas représentée correctement.
- Poses 6 et 8 : accessoire non demandé et changement de silhouette.
- Pose 7 : haut du corps et visage absents, malgré le contrôle technique passé.

fidelity_review.json lie ces observations aux SHA256. Ce contrôle est **une inspection visuelle de l’assistant**, pas un évaluateur automatique dans l’application et pas l’approbation humaine de l’utilisateur. Les contrôles de contraste, résolution et différence ne prouvent pas la conformité des gestes.

Une correction limitée à la pose 7 a été tentée. Qwen a répondu « You have exceeded your ZeroGPU runs limit ». Le fichier initial et les sept autres sont restés inchangés. Aucun service indisponible n’a été présenté comme solution opérationnelle. AnyPose est explicitement exclu du parcours strict tant que cet adaptateur ne possède pas de contrôle de scène validé.

## 4. Corrections du moteur après inspection

- Suppression de la règle qui imposait un sujet unique et empêchait les interactions ou changements de caméra demandés. Le rendu reçoit le registre d’entités et ses invariants.
- Les contacts complexes, occlusions et scènes à plusieurs acteurs ont une image entière par calcul ; les petits lots ne mélangent plus des actions différentes.
- Une image précédente non vérifiée ne sert plus d’ancrage visuel. Cela évite d’imposer au lot suivant une pierre ou une déformation inventée dans le lot précédent.
- Ajout d’une API stricte build_boards : analyse → plan → poses → contrôle → correction ciblée. Une analyse indisponible ou un contrôle non confirmé donne un état bloqué, jamais un succès universel. Cette API métier n’est pas activée comme remplacement de l’écran existant tant que sa fiabilité n’est pas démontrée.
- Correction ciblée avec conservation de l’ancienne image, contrôle des empreintes des voisines et budget de reprise borné. Le succès de cette mécanique est testé avec un rendu simulé ; sa tentative réelle reste bloquée par le quota.
- Conservation des identifiants de travaux en file, réponses terminées et PNG. Le premier essai réel avait été interrompu par un délai d’essai trop court, avant récupération ; le délai a été corrigé et la reprise durable a été ajoutée ensuite. Ce premier calcul interrompu n’est pas annoncé récupéré.
- Canonisation des nombres JSON : une réouverture convertissait les entiers en flottants et pouvait invalider les empreintes du cache. Le cache est maintenant stable et une modification de pose ne change pas le lien des voisines.

Les nouvelles règles de conditionnement sont validées localement, mais leur effet sur une nouvelle planche complète n’a pas été retesté en inférence : le quota est atteint. Les huit images livrées restent donc des candidats rejetés, pas la preuve que ces défauts visuels sont résolus.

## 5. Tests et état final

Godot 4.6.3 : test_universal_board_contract, test_universal_generated_cache, test_hf_studio_generator, test_remote_pose_briefs, test_hf_batch_fallback et test_detailed_style_reference passent. Les tests métier vérifient densité statique/complexe, rôles multiples, temps exact, refus des IDs inconnus et des fausses preuves d’analyse, confidentialité, correction ciblée simulée et préservation des voisins.

Le test HTTP local de reprise passe : trois POST et quatre GET attendus, aucun nouveau POST pour une tâche en attente, résultat terminé réutilisé, et nouveau calcul pour une demande aléatoire de Refaire. Il simule le protocole et n’utilise aucun GPU. Les huit PNG réels ont ensuite été relus avec SHA256 identiques et **zéro nouvel appel d’inférence**.

Aucun test Android, aucune compilation APK, aucun encodage vidéo n’ont été effectués dans cette étape. Les anciens tests API/MP4 inchangés n’ont pas été relancés. Les tests B, C et D **ne sont pas commencés**, car A n’est pas validé.

**La mission universelle n’est pas terminée.** Blocages : analyse et contrôle visuel automatiques non accessibles avec le contrat du service testé, modèle de dessin encore infidèle sur plusieurs poses, quota empêchant leur correction et intermédiaires non générés. Les acquis utiles sont le contrat de scène persistant, le calculateur explicite, les huit candidats et leurs défauts, le moteur de correction sélective et la reprise sans recalcul.


## 6. Reprise : correction réelle bornée et intégration de la branche récente

Les sections 3 à 5 décrivent le premier essai et son quota atteint, pas le résultat de la reprise. Deux nouvelles corrections unitaires Qwen ont ensuite abouti sur la pose 7 seulement. La première restaure le corps entier et retire l’obstacle inventé. La seconde reçoit désormais **le dessin défectueux lui-même**, en plus de la source (et du guide de style si présent) : auparavant la correction ciblée ne transmettait que la description du défaut et la source. Le client identifie cette image comme cible de correction, jamais comme nouvelle identité. Une cible absente bloque la correction. Le contexte temporel non validé reste exclu.

Les sept autres fichiers sont identiques après chacune des deux corrections. Les anciennes versions sont conservées dans history/. POSE_07_CORRECTION_COMPAREE.png présente avant/après. Le dernier PNG est un vrai résultat Qwen 1024×1024 ; le visage et le corps entier sont visibles, sans pierre ajoutée. **Les membres comportent encore des fragments et ramifications : la pose n’est pas validée.** fidelity_review_resumed.json relie cette inspection de l’assistant au nouveau SHA ; fidelity_review.json demeure la revue historique des huit candidats initiaux. La planche initiale n’a pas été régénérée et ne représente pas le nouveau fichier 7.

La requête de reprise du service visuel a échoué dès l’initialisation de conversation, avec une réponse interrompue (ChunkedEncodingError), avant l’envoi d’image. Aucun nouveau résultat d’analyse automatique n’a été obtenu. Pas de nouvelle recherche de moteur ni de boucle de génération.

Tests ciblés de reprise réussis : contrat universel (incluant correction simulée, cible absente et conservation des voisins), protocole HF, brief de scène complète, références de poses, basculement par lots, guide de style avec cible de correction. Le cache relit les huit PNG réels avec des SHA identiques et zéro appel d’inférence, y compris la nouvelle pose. Les indices/longueurs de séquence sont maintenant présents dans les poses du plan strict, comme dans le moteur existant. Le test HTTP local de reprise antérieure est conservé ; pas de relance inutile. Ces tests automatisés ne démontrent pas la qualité sémantique universelle.

A reste non validé ; B/C/D ne sont pas commencés. Le calcul reste 8 poses clés, 51 intermédiaires nécessaires non produits, 150 images vidéo prévues. Aucun test sur téléphone, APK ou MP4 dans cette étape. Le moteur strict reste une API métier bloquante et n’est pas substitué au parcours opérationnel avant preuve de fiabilité.
