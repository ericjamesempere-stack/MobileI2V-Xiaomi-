# V54 — poses distinctes et reprise du contrôle de fidélité

Base vérifiée : ff255e6c24e63c50d878bed60f9afc3058c67d51, branche karma/v54-approval-safety-20261116. Ce commit contient déjà les douze commits postérieurs à 3ae0812. Périmètre : moteur de planches, tests et contrôle continu. Aucun changement du parcours Android, des versions ou de l'export vidéo.

## Changements

- Le plan strict répartit les poses supplémentaires entre les phases physiques. Auparavant une action longue répétait plusieurs fois exactement le même texte de pose. Chaque phase initiale est conservée comme pose exacte ; les poses supplémentaires précisent une progression entre deux états, avec une consigne de dessin unique, sans superposition ou mélange des images. Les instructions unitaires incluent les IDs des acteurs/objets, l'ordre dans la séquence et l'instant demandé.
- Le contrôle visuel est lié à l'empreinte du PNG, à celle de la pose, aux entités, aux relations, à la référence, au style et au fournisseur. Une reprise réutilise les examens conformes et les examens négatifs des dessins inchangés. Les anciens examens sans ce lien ne sont pas repris automatiquement.
- Après une correction réussie, le parcours réexamine le dessin corrigé. Les examens des voisins sont réutilisés. Le résultat peut devenir conforme au contrôle du modèle ; human_approved reste false et ready_for_animation reste false dans build_boards.
- Une référence différente, un plan modifié ou un fichier manquant bloque l'examen avant tout appel au modèle. Les empreintes sont contrôlées avant, pendant et après l'examen ; un changement concomitant empêche de déclarer la séquence conforme.
- Une erreur de sauvegarde du budget de correction bloque le calcul ; les tentatives précédentes restent bornées entre les reprises. Les erreurs de sauvegarde des examens sont remontées.
- Les quatre tests du moteur universel sont ajoutés au workflow Godot existant. Le commit emploie [skip ci] pour éviter les compilations APK et rendus vidéo hors du périmètre demandé ; aucun succès distant n'est affirmé.

## Vérification locale

Godot 4.6.3 : import du projet sans erreur de script, puis dix tests réussis : universal_phase_progress, universal_review_resume, universal_board_contract, universal_generated_cache, board_generation_plan, remote_pose_briefs, full_scene_brief, hf_studio_generator, hf_batch_fallback, detailed_style_reference. git diff --check réussi.

Le test de progression vérifie toutes les répartitions de 2 à 7 phases et jusqu'à 29 poses : aucune consigne répétée, conservation de chaque phase physique, ordre et rôles explicites. Il teste les consignes, pas le rendu d'un modèle.

Le test de reprise utilise un évaluateur et un correcteur simulés, sans réseau. Huit examens initiaux, zéro nouvel examen à la reprise, puis un seul examen après correction de la pose 7 ; les sept autres sont réutilisés. La restauration JSON ne relance aucun examen. Le test couvre également le changement de référence/consigne, la modification du PNG pendant l'examen et le budget de correction déjà consommé.

Le test du cache relit les huit PNG réels préexistants avec les mêmes empreintes et zéro nouvel appel d'inférence. Il ne les rend pas conformes.

## Limites et reprise

Aucune nouvelle inférence réelle n'a été exécutée pour cette étape. Aucun examen automatique réel réussi du fournisseur visuel n'est démontré. Les derniers constats visuels consignés dans validation/v54-universal-a/BILAN.md restent applicables : le test A n'est pas validé, des défauts persistent et les intermédiaires restent à produire. Les tests simulés démontrent la reprise et la sélectivité, pas la justesse universelle des images.

Le moteur strict reste une API distincte ; il n'est pas substitué au parcours Android existant dans cette étape. Aucune nouvelle APK, aucun essai Xiaomi et aucun MP4 livrés. Prochaine validation utile : rétablir un contrat visuel réellement opérationnel, puis vérifier une planche réelle avant de poursuivre les intermédiaires. Ne pas relancer les générations inchangées ni assimiler les contrôles techniques à une conformité des gestes.
