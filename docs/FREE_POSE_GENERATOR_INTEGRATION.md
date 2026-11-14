# MobileI2V — integration gratuite du redessin de postures

## Moteur candidat verifie (documentation publique)
- Hugging Face Space: https://huggingface.co/spaces/abidlabs/Qwen-Image-Edit-2511-AnyPose
- Source: https://huggingface.co/spaces/abidlabs/Qwen-Image-Edit-2511-AnyPose/blob/main/app.py
- Le modele accepte DEUX images : `reference_image` (identite et apparence) et `pose_image` (posture cible). Un simple texte ne remplace pas la pose_image.
- Le code public expose `infer(reference_image, pose_image, prompt, seed, randomize_seed, true_guidance_scale, num_inference_steps, height, width, rewrite_prompt, ...)` via Gradio. Verifier le schema API courant dans le pied de page « Use via API » et OpenAPI avant tout branchement.
- ZeroGPU gratuit MAIS quota journalier et attente : https://huggingface.co/docs/hub/spaces-zerogpu ; aucune promesse de generation illimitee.

## Etat reel du projet
- `scripts/image_sequence_generator.gd` parle actuellement un protocole JSON propre au projet (`image_base64`, `previous_image_base64`, etc.), qui N'EST PAS le protocole Gradio AnyPose.
- Aucune connexion AnyPose fonctionnelle ni generation reelle sur Android n'est encore validee.
- `scripts/story_motion_planner.gd` decompose une histoire en actions, mais il faut ensuite fabriquer une IMAGE DE POSE par etape (silhouette/squelette ou dessin de reference). Les mouvements de la photo detouree ne sont pas des dessins generatifs.
- Ne pas publier les illustrations privees de test dans GitHub.

## Etapes d'integration minimales
1. Generer localement une image de pose explicite pour chaque etape (positions des articulations et cadrage) ; verifier que les images de pose sont DIFFERENTES.
2. Ajouter un adaptateur Gradio asynchrone compatible avec le schema OpenAPI exact du Space : upload des deux images, soumission dans la file, suivi de l'evenement, telechargement de l'image et gestion des erreurs/quota.
3. Utiliser l'original du personnage comme reference identitaire pour chaque etape ; garder la derniere image comme contexte temporel sans substituer aveuglement le resultat a la reference identitaire.
4. Sauvegarder les images en local et montrer une vraie planche de previsualisation ; refuser l'export si la generation echoue.
5. Encoder un MP4 puis verifier `ffprobe` (duree, FPS, nombre d'images), `ffmpeg -f null -` (decodage) et la lecture sur Xiaomi 14T Pro.

## Critere de validation
Photo privee du personnage accroupi + « il se releve, court puis tombe » -> au moins 3 dessins distincts du MEME personnage dans des postures nouvelles, une planche consultable et un MP4 lisible. Aucune affirmation « IA validee » avant execution de ce scenario. La simple reussite de GitHub Actions ne prouve pas ce test.
