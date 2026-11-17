# KARMA ONE V57 — reprise du 17 novembre 2026

Base conservée : V56 `cdb4f5f03a30fcf947540cbf18f1efe31c85bafe`, après V55/V54/V53 et Autopilot V2. Même application, mêmes projets, même parcours de validation. Identité Android : versionCode 12, versionName 1.5.7 (V57 Local).

## Corrections livrées

- Le mode local enchaîne les lots de quatre dessins intermédiaires et leurs contrôles jusqu'à la fin de la séquence. Il s'arrête sur erreur, rejet visuel ou absence de progression. Chaque dessin sauvegardé reste réutilisable après une coupure. Le mode distant conserve son budget par appel.
- Les longues instructions d'édition et les registres de scène ne sont plus envoyés directement au modèle SD1.5. Le modèle local MNN les transforme en une courte description visuelle anglaise, en recevant l'image originale, le style, les personnages et la phase demandée. La limite CLIP est mesurée par `/tokenize` avant diffusion. Un seul raccourcissement est permis ; une réponse invalide ou encore trop longue bloque la génération sans altérer les dessins.
- L'erreur du moteur pendant les intermédiaires est maintenant affichée dans l'écran de reprise.
- Garder / Refuser / Refaire, les contrôles de fidélité, le cache existant, la galerie et l'export MP4 restent dans le parcours existant. Aucune approbation automatique.

## Preuves exécutées dans l'environnement de développement

Godot 4.6.3 :
- Transport HTTP local : huit poses, neuf intermédiaires, trois lots automatiques, création du sujet, correction ciblée, contrôle, sauvegarde et reprise. Deux scénarios : nominal et coupure au deuxième lot suivie d'une reprise sans recalcul des dessins conservés. Réponses des modèles SIMULÉES, aucun appel distant.
- Dix cas de préparation des consignes : succès, raccourcissement, dépassement persistant, JSON invalide, panne vision/tokenizer, compte négatif/fractionnaire, budget plus petit, création texte. Modèles SIMULÉS.
- Tests de budget Autopilot, mémoire technique et écran simplifié : réussis.
- Intégration jusqu'au MP4 : H.264 96×160, 30 FPS, 150 images, 5 secondes, décodage complet réussi. Dessins et MediaCodec SIMULÉS ; encodeur FFmpeg réel. Ce film technique ne prouve pas la fidélité de dessins IA.

La compilation Android et la suite Godot 4.5.2 sont exécutées par le workflow du commit livré. Vérifier le résultat du workflow avant de considérer l'APK comme compilé ; ce document n'anticipe pas son résultat.

## Démarrage sur le téléphone

Utiliser l'APK final signé avec le certificat V55, sans désinstaller l'ancienne version V55. Les étapes de configuration de `validation/v56/INSTALLATION_XIAOMI.md` restent applicables : MNN Chat avec modèle vision et API 127.0.0.1:8080, puis Local Dream avec modèle SD1.5 CPU/img2img et API 127.0.0.1:8081. La création d'un sujet texte utilise aussi MNN pour traduire et condenser la consigne. Le moteur Local Dream doit exposer `/tokenize`, sinon la consigne ne peut être vérifiée et la génération s'arrête explicitement.

## Limites encore non levées

L'APK n'embarque ni les moteurs externes ni leurs poids. La génération réelle avec cette combinaison sur le Xiaomi, la fidélité des visages et des actions, la mémoire/chauffe/vitesse, la galerie tactile et MediaCodec matériel n'ont pas été testés ici. Aucun nouvel exemple IA n'est présenté comme validé. Cette livraison corrige deux obstacles concrets ; elle ne constitue pas une preuve d'application universelle autonome terminée.

Contrat officiel du moteur : https://ld.chino.icu/features/http-api (limite de 77 tokens et endpoint `/tokenize`).

## Signature de mise à jour

Défaut découvert après la première compilation : les caches Actions sont isolés par branche. V55, V56 et le premier candidat V57 ont trois certificats différents ; conserver le même identifiant Android ne suffit pas pour une mise à jour. Le premier APK V57 n'est pas retenu pour livraison.

La publication de V57 utilise donc la branche existante `karma/v55-finalisation-20261117`, avancée sans réécriture d'historique jusqu'au code V57. Le workflow y vérifie le certificat SHA256 V55 `5fe844e7ae98d51d5464f1e3a7d58e218aeade4c11b8fe4a1c5ed5e45d9663ef` avant publication. L'audit pointe cette branche de publication ; les commits et fichiers V53 à V56 restent conservés. Pour les prochaines mises à jour, continuer sur cette branche afin de réutiliser la même clé, tant qu'aucune clé de publication persistante n'est configurée.

Compatibilité de mise à jour prouvée ici : certificat V55. La V56 utilise un autre certificat (`e6cb24642e64935654e0ac7b82e87db7be3e937bc4a104cd86de73446f0d78c1`) ; cet APK V57 ne peut pas remplacer directement une V56 déjà installée avec cette signature. Ne pas désinstaller une application contenant des projets pour forcer l'installation.
