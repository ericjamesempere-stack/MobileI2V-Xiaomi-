# KARMA ONE · Validation de la mission MobileI2V

Branche `karma/advanced-autonomy-integration-20261118`. Base V60 `656d13907e593db060309cffda505da76d507b4c`. Code de la mission vérifié à `af673c0cd949a074a3300411113cca7fa98178e5`.

## Résultat du premier cycle

1. L’inventaire Git a enregistré le HEAD, les branches et l’empreinte des sources. Le graphe MobileI2V dans `autopilot/tasks.json` contient 14 tâches ordonnées par dépendances.
2. Le code candidat a été testé à partir de son SHA dans un checkout détaché. Les fichiers du plan, des tests, des permissions et de CI restent dans le périmètre du code de confiance. Le rapport contient la base, le candidat, le manifeste et les preuves de chaque test.
3. Le correctif MobileI2V a produit `REVIEW_REQUIRED` avec 14 succès. Le garde V60 a autorisé la revue et l’agent de test V60 l’a rendue dans un processus séparé. Le test vérifie la production d’une décision et ses preuves.
4. Pour la contre-épreuve, un commit temporaire forçait le refus des dessins pourtant validés. Le test Godot d’approbation a échoué. L’agent a rendu `REJECT`, l’export a été bloqué par une dépendance et le checkout jetable a été retiré. La base est restée au même SHA.
5. La mémoire a récupéré les 14 résultats d’une exécution réussie après redémarrage. Un test injecte une interruption après un premier succès, puis vérifie que seul le travail interrompu reprend. La migration préserve les tentatives V2. Une empreinte invalide, une entrée de cache sans journal ou un résultat échoué empêchent la réutilisation.
6. Dans le parcours Android, si le sélecteur reste en état `selecting` après le retour du focus, l’attente s’arrête après 45 s, le bouton se libère et le projet est conservé. Durant la sélection hors focus, ce délai est suspendu. Pour une création d’image qui échoue, le message présente le parcours assisté ChatGPT déjà disponible. Le message de succès requiert désormais une nouvelle référence effectivement chargée et un aperçu.

## Vérifications reproductibles

À la racine du dépôt, dans un environnement de test avec Godot et FFmpeg.

```bash
godot --headless --path . --editor --import --quit
python3 -m unittest discover -s tests -p 'test_autopilot.py' -v
python3 autopilot/supervisor.py --state /tmp/karma-check/technical.db --report-dir /tmp/karma-check/reports
python3 autopilot/supervisor.py --state /tmp/karma-check/technical.db --report-dir /tmp/karma-check/reports
python3 tests/test_local_engine_probe.py
python3 -m autopilot.candidate FULL_CANDIDATE_SHA --state /tmp/karma-check/technical.db --report-dir /tmp/karma-check/candidate
```

Le mode candidat utilise comme base le checkout propre depuis lequel il est lancé. Le commit candidat est un descendant local, issu d’une source de confiance. Une revue favorable autorise uniquement la transmission à l’opérateur pour décision. Les règles de périmètre sont dans `autopilot/candidate.py`.

Sur le SHA GitHub, 84 tests Python ont réussi, dont les 17 du superviseur. Les 14 tâches Godot/Git ont réussi avec Godot 4.5.2 et FFmpeg 8.1.3. Les six scénarios HTTP de la sonde sont passés avec un serveur fixture sur loopback et zéro requête POST. Les reçus des runs de démonstration portent les SHA locaux. Leurs arbres Git contiennent les mêmes modules que le commit de livraison et les modifications expérimentales documentées.

## Matrice A01–A16

| ID | État | Preuve ou limite |
|---|---|---|
| A01 | PASS | Inventaire des agents, responsabilités, appelants et tests, plus inventaire des refs. |
| A02 | PASS | DAG versionné MobileI2V et 14 reçus. La décomposition a été configurée pour ce projet. |
| A03 | PASS | Le garde refuse `merge_protected_branch` au rôle de test. Le superviseur refuse les champs de commande et les capacités arbitraires. |
| A04 | PASS | Régression d’export injectée, rejetée par l’agent. Base inchangée et worktree de revue retiré. |
| A05 | PASS | Interruption injectée après une tâche, tentative réservée sur disque et reprise limitée au travail restant. Tests locaux sans effets externes. |
| A06 | BLOCKED | Réutilisation démontrée pour 14 preuves à signature identique. La sélection et la réapplication d’un correctif connu à une autre révision ne sont pas implémentées. |
| A07 | PASS | Échec exclu du cache et cache falsifié sans preuve journalisée ignoré. |
| A08 | PASS | Budget temporel et deux tentatives, concurrent interdit sur la même base, reprise après arrêt testée. |
| A09 | PASS | Candidat préparé séparément, garde et code-test V60 exécutés dans un processus de revue distinct. Une décision humaine reste nécessaire pour intégrer un futur candidat. |
| A10 | PASS | Scénarios locaux de modèle absent, authentification et santé vérifiés. Les fixtures ne produisent aucune prétendue image IA. |
| A11 | BLOCKED | Délai de retour, aperçu, sauvegarde et réouverture validés sous Godot. Le sélecteur, la rotation et la reprise HyperOS nécessitent un Xiaomi physique. |
| A12 | BLOCKED | Aucun modèle génératif configuré et exécuté pour cette validation. |
| A13 | BLOCKED | Tests de planches et remplacement ciblé sur fixtures. Fidélité et continuité d’un rendu génératif réel en attente. |
| A14 | PASS | Garder/Refuser/Refaire, modification du fingerprint et blocage de l’export vérifiés sous Godot. |
| A15 | PASS | Contrôle technique sur un MP4 de fixture H.264, 96×160, 150 images, 30 i/s, 5 s, décodage intégral FFmpeg. Encodage MediaCodec et animation générative réelle restent à vérifier. |
| A16 | BLOCKED | APK ARM64 debug compilé et signé. Son certificat diffère de celui de V60 et l’installation physique reste à vérifier. |

## Mesures et périmètre

| Mesure locale | Avant / première exécution | Après / reprise |
|---|---:|---:|
| Réservation SQLite dans une base de 5 000 événements, médiane de 21 réservations après ouverture | V60 12,692 ms | Nouvelle version 0,070 ms |
| Même DAG MobileI2V de 14 tâches et même SHA | 15,976 s à froid | 0,251 s, 14 preuves réutilisées |

Ces mesures portent sur l’orchestrateur sur cette machine. La qualité, l’énergie et la vitesse d’inférence ou d’encodage sur Xiaomi restent à mesurer.

Le plan exécute des contrôles déterministes, révise un commit fourni et conserve les preuves. La production autonome d’un nouveau patch, l’apprentissage général entre dépôts et la validation d’un moteur IA réel restent à réaliser. Le contrôle de sécurité porte sur les permissions, les fichiers admissibles, le journal, les preuves, les redirections du test de sonde et le diff Git. Il ne fournit pas un audit exhaustif des dépendances. Aucun abonnement ni service payant n’a été utilisé.

## Compilation Android

La première CI a échoué au test d’export lancé avant la disponibilité de FFmpeg. Une reproduction locale sous Godot 4.5.2 confirme la différence avec et sans FFmpeg sur le PATH. La deuxième CI a atteint le délai de l’étape qui installait les paquets vidéo. La branche réutilise désormais FFmpeg et FFprobe si disponibles. Sinon elle récupère une version figée, contrôle son SHA-256 et vérifie les deux exécutables avant le test. Ce parcours a été testé localement avec les exécutables issus de l’archive.

- [Premier build CI](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44206025105)
- [Deuxième build CI](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44206867170)
- [Build du commit livré](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44208954732)


### APK ARM64 de test

Le build a produit un APK de 88 039 409 octets. Le fichier téléchargé correspond
au SHA-256 du workflow et son archive contient uniquement les bibliothèques
ARM64. Les 11 tests Java du plugin ont réussi en CI.

| Valeur contrôlée | Résultat |
|---|---|
| Paquet | `com.ericjamesempere.mobilei2v` |
| Version Android | `15`, 1.6.0 (V60 Simplified) |
| APK SHA-256 | `06ef4b622ae82eb412a2f8418570f373fa5feb9b767b4fbbc8dee29c3b5985f2` |
| Certificat debug SHA-256 | `e11f08c4090d00bfb2211e3f790a32702891a43e8b51533ae0643e4d8486a6d7` |
| Certificat de la V60 distribuée | `5fe844e7ae98d51d5464f1e3a7d58e218aeade4c11b8fe4a1c5ed5e45d9663ef` |
| Installation sur Xiaomi 14T Pro | En attente |

Le certificat diffère de celui de la V60 distribuée. Android refusera cet APK
comme mise à jour de cette V60. Garde l’application installée et tes projets.
Le fichier livré est destiné à un environnement de test où ce paquet est absent.

[Artefact GitHub et rapport de signature](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44208954732/artifacts/14385003246)
