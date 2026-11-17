# KARMA ONE V56 — démarrage gratuit sur Xiaomi 14T Pro

Cette version poursuit le choix local : KARMA ONE garde l'interface, les projets et les contrôles. Le calcul reste sur le téléphone ; il dépend de moteurs et de modèles séparés. Aucun abonnement ni API payante n'est ajouté.

## Installation initiale

1. Installer l'APK KARMA ONE V56 comme mise à jour de V55, sans désinstaller l'application pour préserver ses données. La signature de debug et l'identifiant du paquet restent ceux de la chaîne de compilation.
2. Installer [MNN Chat depuis sa page officielle](https://github.com/alibaba/MNN/blob/master/apps/Android/MnnLlmChat/README.md#releases). Profil vision retenu : **Qwen2.5-VL-3B-Instruct-MNN**, présent dans le catalogue officiel, à télécharger en Wi-Fi (environ 2,74 Go de fichiers selon ce catalogue ; ce chiffre ne mesure pas la RAM). Sa vitesse, sa mémoire et sa fidélité sur le Xiaomi restent à vérifier. Un modèle texte seul ne suffit pas.
3. Dans MNN Chat, activer le service API sur **127.0.0.1:8080**, garder son authentification et copier sa clé locale dans **KARMA ONE → Réglages et outils → Clé locale MNN Chat**. Cette clé donne accès au moteur du téléphone ; elle n'est pas un paiement. Elle reste dans la session et n'est pas enregistrée dans le fichier de projet.
4. Installer [Local Dream depuis les releases officielles](https://github.com/xororz/local-dream/releases/latest). Télécharger un modèle **SD1.5 CPU** et ses composants img2img, activer l'image-vers-image, puis ouvrir le modèle pour démarrer le moteur. Son serveur de génération utilise **127.0.0.1:8081**. Ne pas activer le partage LAN ou le mode hôte pour KARMA ONE.
5. Dans KARMA ONE, conserver **moteurs du téléphone**, puis toucher **Réglages et outils → Vérifier les moteurs du téléphone**. Un HTTP 200 ne prouve ni la présence de tous les poids ni la qualité du modèle : le diagnostic le précise.

Après cette préparation, le parcours habituel de KARMA ONE reste le même. Si Android arrête un moteur en arrière-plan, le rouvrir et vérifier de nouveau ; les images existantes sont conservées.

## Premier essai utile

- Commencer avec une seule image et une action courte, sans référence de style séparée (non supportée par l'adaptateur local actuel).
- Vérifier le visage, les vêtements, les formes, le nombre de sujets, le décor et une véritable différence de posture. Un zoom ne valide pas une action.
- Refuser/refaire les dessins incorrects. Garder chacun des dessins conformes, puis confirmer la planche avant l'export MP4.
- Tester ensuite la banane sans anatomie humaine ajoutée et une scène multiple. Ne considérer la fin de mission acquise qu'après ces trois résultats réels.

## Lire le diagnostic

- **401/403 MNN** : recopier la clé du service local dans le champ privé.
- **Aucun modèle** : charger un modèle vision dans MNN Chat et relancer son API.
- **Local Dream indisponible** : ouvrir le modèle CPU, vérifier img2img et le service actif.
- **Connexion vérifiée** : les API répondent ; l'analyse, le redessin et la fidélité restent à tester.

**Copier le diagnostic local** permet de transmettre les états, codes HTTP et nom du modèle annoncé. Il ne copie aucune image, consigne ou clé.

## Ce qui n'est pas promis

La limite des quotas externes est évitée quand le calcul est local, mais le téléphone consomme toujours du temps, de la mémoire et de l'énergie. SDXL peut demander davantage de mémoire ; il n'est pas sélectionné automatiquement par ce profil initial. Les chemins NPU/DiT optimisés pour Snapdragon ne sont pas présentés comme compatibles avec le MediaTek.

Cette installation physique ne peut pas être réalisée depuis l'environnement de développement actuel. Les tests livrés vérifient le transport et les garde-fous avec des réponses simulées ; ils ne remplacent pas un modèle réellement chargé sur le Xiaomi.
