# Test GPU gratuit MobileI2V (Google Colab)

Ouvrir le notebook : [MobileI2V_SD_Turbo_Test.ipynb](./MobileI2V_SD_Turbo_Test.ipynb).

Dans GitHub, sélectionner **Open in Colab** si disponible, sinon ouvrir [Google Colab](https://colab.research.google.com/) > **GitHub**, chercher `ericjamesempere-stack/MobileI2V-Xiaomi-`, choisir la branche `karma/storyboard-story-sequence-20261113` et le notebook `colab/MobileI2V_SD_Turbo_Test.ipynb`.

1. Choisir **GPU T4** si Colab en propose un.
2. Lancer les cellules, importer une photo, puis éditer `histoire` et `nombre_images`.
3. Le notebook télécharge `mobilei2v_images_ia.zip` contenant les PNG générés et la consigne.
4. Vérifier si le personnage reste reconnaissable et si les poses changent réellement.

**Limites** : Google Colab gratuit a des ressources et durées variables. Ce notebook ne constitue pas un serveur disponible 24 h/24. Il ne branche pas automatiquement les images à l'application Android. SD-Turbo img2img ne suit pas un squelette : des changements de pose, de visage ou de vêtements peuvent être incohérents. Commencer par six images pour limiter le temps GPU.

**Confidentialité** : la photo est transmise à l'environnement Colab choisi et les poids du modèle sont téléchargés depuis Hugging Face. Éviter les photos sensibles si cette transmission ne convient pas.

**Coût** : aucun abonnement ou paiement exigé par le notebook, mais disponibilité GPU gratuite non garantie.
