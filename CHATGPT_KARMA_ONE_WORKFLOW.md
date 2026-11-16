# ChatGPT → KARMA ONE → MobileI2V (sans API)

## Mode opératoire
1. Dans ChatGPT, préparer les images successives du même personnage (même cadrage, format et style). Les nommer `frame_0000.png`, `frame_0001.png`, etc.
2. Placer les fichiers dans **un même dossier accessible à Android** (par exemple Downloads/MobileI2V).
3. Dans le studio, appuyer sur **IMPORTER UN DOSSIER DE DESSINS CHATGPT (KARMA ONE)** et sélectionner ce dossier.
4. Vérifier la planche et la durée, puis appuyer sur **EXPORTER LE FILM MP4 (APRES VERIFICATION)**.
5. Si le plugin Android MP4 n'est pas présent, utiliser l'export AVI de secours. L'export MP4 doit être vérifié sur appareil réel.

## Réalité technique
- ChatGPT ne peut pas être piloté automatiquement par cette application sans API. L'import est manuel, mais le classement et la sauvegarde sont automatiques.
- L'import ne génère **aucun dessin**. Il accepte les images existantes PNG/JPG/WEBP, triées par nom, dans la limite de 240.
- Les images sont copiées dans `user://projects/chatgpt_import_*` avant export et le projet est sauvegardé.
- L'export vidéo répète des dessins clés pour tenir la durée : il ne synthétise pas automatiquement des poses anatomiques intermédiaires.
- Les séquences de plus de 240 dessins demandent une autre stratégie de stockage et de lecture.
- Aucun abonnement, API ou GPU externe n'est requis pour l'import et le montage.
- **Non vérifié sur Xiaomi 14T Pro** : sélection native de dossiers, compilation APK, autorisations Android et sortie MP4. Un test sur l'appareil est indispensable avant de déclarer l'application terminée.
