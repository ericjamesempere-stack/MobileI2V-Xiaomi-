# MobileI2V — Plan de finalisation a cout zero (decision technique)

## Decision
Ne PAS essayer de generer 24 ou 30 images IA par seconde via ZeroGPU. Le quota quotidien gratuit est trop faible pour promettre plusieurs minutes de video. Faire des images clefs de mouvements, puis calculer les intermediaires localement. Ce calcul doit etre **articule** (positions anatomiques, bras/jambes/torse) et non une deformation de l'image complete.

## Voie A : moteur distant pose-conditionne
- Modele candidat: https://huggingface.co/spaces/abidlabs/Qwen-Image-Edit-2511-AnyPose
- Contrat conceptuel : photo identitaire + image de posture + instruction -> image clef du personnage.
- Verifier au moment de l'integration le schema exact dans « Use via API » / OpenAPI, la disponibilite et l'authentification. Ne PAS supposer qu'un POST JSON image_base64 au Space fonctionne : Gradio utilise normalement upload de fichiers + soumission queue + suivi evenement.
- Le token Hugging Face eventuel appartient a l'utilisateur ; ne jamais l'ecrire dans le code, les logs, ou les commits.
- ZeroGPU: https://huggingface.co/docs/hub/spaces-zerogpu ; quotas gratuits, files d'attente, indisponibilites possibles.
- Sans acces distant verifie, afficher « Service gratuit indisponible » ; ne pas produire une fausse image IA.

## Voie B : animation locale, sans quota
- Story planner -> timeline de postures explicites.
- Corps articule / IK avec angles et positions pour se relever, courir, tomber, etc.
- Redessiner chaque image dans un style vectoriel/cartoon local si aucun modele IA n'est disponible.
- Uniquement les images reellement distinctes peuvent etre comptees comme dessins ; pas de vagues/zoom/crossfade trompeur.
- Ce mode ne reproduit pas fidelement la photo ; ne pas le presenter comme un redessin photorealiste de la personne.

## Verrous techniques
1. `scripts/image_sequence_generator.gd` transmet maintenant `pose_image_base64`, mais son endpoint JSON n'est PAS le protocole Gradio AnyPose.
2. `backend/image_server.py` refuse explicitement les guides de pose (HTTP 501) : SD-Turbo n'est pas un modele pose-conditionne.
3. `zerogpu/app.py` utilise SD-Turbo sans ControlNet/AnyPose et ne doit pas etre presente comme une solution de conservation de la posture.
4. La generation de guides `procedural_cartoon_generator.gd` est rudimentaire. Elle ne garantit pas un mouvement anatomique convaincant.
5. Une compilation Android reussie n'est pas un test du service distant ni de la fluidite du film.

## Critere de fin
Une photo privee + « se releve, court, tombe » -> au moins 3 images clefs nouvelles du meme personnage, mouvements continus valides visuellement, MP4 decode et lu sur Xiaomi 14T Pro. Sinon marquer la fonction « prototype », pas « terminee ».

## Sources
- https://huggingface.co/docs/hub/spaces-api-endpoints
- https://huggingface.co/docs/hub/spaces-zerogpu
