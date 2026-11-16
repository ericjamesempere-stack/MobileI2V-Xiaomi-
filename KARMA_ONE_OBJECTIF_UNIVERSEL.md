# KARMA ONE V54 — objectif permanent et critères de livraison

Instruction utilisateur confirmée le 16 novembre 2026. Ce document fixe le périmètre à conserver lors des prochaines interventions. Il ne certifie pas que les fonctionnalités ci-dessous sont terminées.

## Objectif

Un seul studio universel dans l'application existante :
- Depuis une image choisie dans la galerie, une photo ou une illustration : préserver les éléments de référence conformément à la demande.
- Depuis une idée textuelle seule : créer l'image initiale puis les planches, sans obliger à inventer un héros ou un personnage humain.
- Accepter des humains seuls ou en groupe, animaux, créatures, objets, véhicules, paysages, interactions et transformations explicitement demandées.
- Comprendre la demande et produire un nombre adapté d'illustrations distinctes avec continuité, identité, vêtements, proportions, style et environnement cohérents.
- Autoriser les changements de décor, de caméra ou d'apparence lorsqu'ils sont demandés ; ne pas les traiter systématiquement comme des défauts.
- Montrer les planches et chaque dessin en détail ; Garder, Refuser et Refaire ciblent les images concernées, sans recalculer les voisines correctes.
- Conserver le projet et reprendre après interruption. Préserver la validation obligatoire existante.

La séquence « accroupi → debout → marche → course » est UN cas de validation, pas le périmètre du produit. Huit dessins ne constituent pas un nombre universel imposé.

## Contraintes

Conserver la branche karma/v54-approval-safety-20261116 et les acquis V53/V54. Ne pas reconstruire, revenir à V50, créer une autre application ou un second parcours. Réutiliser universal_board_pipeline.gd, storyboard.gd et les adaptateurs existants.

Priorité exclusive : image initiale, générateur de dessins, planches, qualité, import et réactivité Android. Ne pas développer de nouvelles fonctions vidéo pour contourner les défauts de génération.

Budget utilisateur : aucun achat ni abonnement/API payante ajouté sans demande. Ne pas promettre la suppression des limites physiques : calcul local implique temps, mémoire et chauffe ; calcul distant implique disponibilité et quotas. Ne pas contourner les restrictions des fournisseurs.

## Architecture à conserver et raccordements à terminer

1. Entrée image OU idée → référence sauvegardée → même moteur universel → planches → examen → correction ciblée.
2. Texte seul : réutiliser create_reference puis le pipeline existant. Lever la restriction UX au seul « personnage ». Vérifier le parcours existant avant toute modification.
3. Analyse : conserver un véritable modèle multimodal pour inventorier la scène et comprendre la demande. Réparer le contrat du fournisseur existant avant de chercher un remplacement. Contrôler la configuration et les réponses réellement reçues ; ne jamais remplacer un échec par une fausse analyse.
4. Génération : Qwen Image Edit pour le redessin conditionné et Z-Image Turbo pour l'image initiale sont les adaptateurs distants présents. AnyPose reste non validé pour le parcours strict et ne doit pas être annoncé opérationnel.
5. Fidélité : confronter chaque résultat à la référence ET à la demande. Corriger uniquement les défauts, avec budget borné, historique et conservation des empreintes des voisins.
6. Réactivité : conserver les miniatures bornées et PNG complets sur disque. Mesurer le chargement, décodage, redimensionnement et sauvegarde ; déplacer hors du fil de l'interface les opérations coûteuses identifiées, en laissant les modifications de scène/UI au fil principal. Éviter de charger toutes les images en pleine définition.
7. Import Android : utiliser le sélecteur natif existant, préserver l'ancienne image lors d'une annulation/erreur, gérer l'orientation et les URI, prévenir les opérations concurrentes, vérifier sauvegarde et reprise.
8. Moteurs locaux : le raccordement MNN Chat/Local Dream existe, mais exige applications et modèles séparés. Il n'est pas la preuve d'une application autonome ni d'une qualité équivalente à ChatGPT sur Xiaomi.

## Constats vérifiés sur a07fe45c27f8ac90fe3f72f50ca911f7e4d0a1bf

- Les deux entrées existent déjà en code : _friendly_generate appelle _create_remote_reference si nécessaire, puis _draw_remote_story ; ce dernier appelle universal_board_pipeline.build_boards.
- Le parcours texte exige actuellement character_description et présente un « héros » : restriction d'interface à traiter pour les idées générales.
- Le parcours strict appelle réellement l'analyse avant les dessins et bloque sur son échec ; les derniers rapports documentent des échecs du service visuel.
- _drawing_thumbnail limite le grand côté à 320 pixels ; la planche affiche au plus 48 miniatures. L'examen individuel existe.
- Certaines lectures/redimensions/sauvegardes d'images se trouvent dans les méthodes de l'écran. Leur impact sur le fil principal doit être mesuré ; aucun profil de performance Xiaomi ne permet encore de garantir l'absence de pauses.
- Les huit PNG existants de validation/v54-universal-a sont d'anciens candidats Qwen de banane course/trébuchement/chute, rejetés pour plusieurs défauts. Ils ne prouvent ni le cas humain accroupi/course, ni l'universalité.
- CI de ce commit : compilation APK ARM64 réussie, tests Godot réussis, 12 contrats API réussis. Les tests d'intégration utilisent des réponses IA simulées et ne démontrent pas la qualité du moteur.
- Aucun essai physique Xiaomi 14T Pro établi par ces résultats.

## Validation minimale représentative

Ne pas relancer les anciens tests inchangés sans raison. Pour chaque correction, exécuter les tests ciblés et produire les preuves correspondantes.

| Cas réel | Entrée | Contrôle essentiel |
| --- | --- | --- |
| Personnage et mouvement | Image de référence | Identité, vêtements, proportions, poses, continuité |
| Animal | Image ou idée | Anatomie propre à l'animal, absence de corps humain imposé |
| Objet ou véhicule | Idée seule | Création initiale puis planches cohérentes, géométrie |
| Plusieurs sujets | Image et histoire | Nombre, identités, interactions, absence de fusion |
| Décor ou transformation | Idée ou image | Respect du changement demandé et des invariants restants |

Ces essais sont une couverture représentative, pas une preuve mathématique de réussite sur toute demande.

Pour chacun : conserver l'entrée, le texte, le moteur exact, les vrais PNG, les métadonnées de génération, les résultats de contrôle et la planche affichée. Toute image hors KARMA ONE reste explicitement une référence de qualité, jamais une preuve du moteur intégré.

Référence de qualité : illustrations détaillées comparables aux planches appréciées par l'utilisateur dans ChatGPT. Évaluer visuellement trait, détails, anatomie/géométrie, composition, fidélité et continuité. Un prompt plus long, un score de contraste ou un agrandissement ne prouvent pas cette qualité.

Essais Android : sélection galerie, annulation, réimport, grosse image, orientation, sauvegarde/reprise, examen/Refaire, absence de plantage, mesures mémoire et réactivité. Si le Xiaomi n'est pas accessible, déclarer ces essais non effectués et ne pas certifier leur réussite.

## Livraison et statut

Livrer les vrais PNG, planches, moteur utilisé, examen de fidélité, correction ciblée démontrée, commit, résultats exacts des tests, APK si compilation réussie et limites restantes.

Statut à la rédaction : objectif NON atteint. La session ayant enregistré ce document dispose de l'accès GitHub mais d'aucun environnement local d'exécution utilisable ; aucune nouvelle inférence, correction de code ou mesure matérielle n'y a été exécutée. Ce document est un engagement de périmètre et un plan de finalisation, pas une annonce de réparation.
