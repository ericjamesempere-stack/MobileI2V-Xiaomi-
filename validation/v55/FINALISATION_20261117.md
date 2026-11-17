# KARMA ONE V55 — validation réelle et blocages

Base : karma/universal-text-entry-v55-20261117, commit 7c791dc02ea6fcdb3621aa4b548d07ad1b6fd9b2. Les acquis V53/V54/Autopilot V2 sont conservés.
Branche de livraison : karma/v55-finalisation-20261117. Nouvelle identité APK : versionCode 10, versionName 1.5.5 (V55). Le nom interne du projet est conservé pour ne pas changer volontairement le répertoire utilisateur Godot.

## Défaut identifié et corrigé

Le build 44008779470 échouait dans test_friendly_studio.gd : la fixture de génération fournissait 64×64 pixels alors que le garde V55 exige au moins 256×256. La fixture valide fournit maintenant 512×512 ; les cas succès sans image et image trop petite sont exercés séparément et doivent conserver la référence précédente, sans appeler le storyboard. Le garde de production n'est pas abaissé.

Les cinq contrats Python V55 passent. Le test comportemental Godot du véritable écran passe après correction. Le nouveau nom du build est également raccordé à l'audit Autopilot existant.

## Inférences réellement exécutées

| Cas | Fichiers réellement produits | Examen visuel / résultat |
|---|---|---|
| Photographie humaine publique | Photo NASA distribuée par scikit-image → Qwen Image Edit → deux dessins de 512×1024 et planche 1024×1024 | FAIL artistique : visage rajeuni et modifié entre les cases, cadrage et détails de combinaison dérivent. Les pixels sont réels ; la fidélité n'est pas validée |
| Banane vivante | Z-Image-Turbo → référence 1024×1024 ; Qwen Image Edit → deux dessins et planche | Anatomie non humaine conservée, aucun torse humain ajouté. FAIL mouvement : la flexion demandée n'est pas démontrée ; décor et cadrage dérivent |
| Plusieurs personnes / objets / mouvement | Essai de création d'une scène avec deux personnes, vélo, chien et ballon : quota épuisé. Second essai avec photo publique de piétons et bus : le redessin est également bloqué | BLOCKED : quota Qwen explicite, fallback AnyPose en erreur masquée. Aucune planche inventée en remplacement |

Ces essais ont appelé les méthodes de génération existantes de hf_studio_generator.gd, avec des consignes de test explicites. Ils ne prouvent PAS une analyse sémantique automatique ni le parcours Android complet. Aucune image n'a été approuvée automatiquement pour contourner l'export.

## Vision et quota

- Le service Qwen vision a été comparé avec son client Gradio officiel, via queue/join : le fournisseur renvoie toujours une exception dont il masque la cause.
- Une alternative SmolVLM officielle a été testée ; son client officiel révèle : « You have exceeded your ZeroGPU runs limit. Authenticate with a Hugging Face token for more quota ». Aucun contournement de quota ni nouvelle tentative identique.
- Aucun connecteur Hugging Face utilisable n'a été trouvé dans les intégrations disponibles.
- Les résultats, planches, photographies publiques et traces des appels sont remis dans le dossier de preuves privé ; aucun secret ni photo personnelle n'est publié dans cette branche.

## Reproduction contrôlée

Le script tools/test_v55_real_cases.gd réutilise les générateurs existants et exige KARMA_ALLOW_LIVE_INFERENCE=1, KARMA_V55_EVIDENCE_DIR ainsi que trois références explicites : KARMA_V55_HUMAN_REFERENCE, KARMA_V55_BANANA_REFERENCE et KARMA_V55_COMPLEX_REFERENCE. KARMA_HF_TOKEN, facultatif, doit être fourni par un canal de secrets local ; ne jamais le committer ou l'inscrire dans les rapports.

La sortie complete signifie seulement que les fichiers image ont été produits, jamais que la fidélité est validée. Les caches sont liés aux références/consignes et les moteurs indisponibles ne sont pas réessayés pour chaque cas. Aucun appel GPU dans le build standard.

## Fin de mission non acquise

La compilation et les tests techniques sont vérifiés séparément par le build de cette branche. La qualité artistique, les mouvements fidèles, la vision automatique et le Xiaomi réel restent FAIL / BLOCKED / NOT_TESTED selon les preuves. Un MP4 de contrôle contenant des dessins IA ne doit pas être présenté comme un film fidèle validé.

L'intervention utile pour continuer les essais distants est un accès gratuit authentifié avec quota disponible, ou un moteur local compatible réellement chargé. L'authentification ne garantit ni quota illimité ni qualité suffisante. Les essais physiques nécessitent également le Xiaomi ; ils ne sont pas remplacés par CI.

Sources des références publiques :
- https://raw.githubusercontent.com/scikit-image/scikit-image/v0.24.0/skimage/data/astronaut.png
- https://github.com/scikit-image/scikit-image/blob/v0.24.0/skimage/data/README.txt
- https://raw.githubusercontent.com/ultralytics/ultralytics/main/ultralytics/assets/bus.jpg
- https://github.com/ultralytics/ultralytics/blob/main/LICENSE
