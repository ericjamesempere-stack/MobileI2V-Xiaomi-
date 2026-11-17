# KARMA_ONE_V56_LOCAL_20261117_0521

Base conservée : V55 75af13f1f714b2e0edbe94fc0574a661c303942e, avec les acquis V53/V54 et Autopilot V2. Nouvelle branche : karma/v56-local-engines-20261117. Android versionCode 11 / versionName 1.5.6 (V56 Local).

- Conservation du parcours unique photo/description → analyse → dessins → planches → Garder/Refuser/Refaire → validation → MP4.
- Mode local conservé par défaut. Aucune bascule automatique vers un service en ligne, aucun appel GPU distant dans les tests.
- Contrôle préalable rapide des deux API locales, sans transmettre d'image ni de consigne : modèle actif MNN Chat, réponse HTTP Local Dream. Les métadonnées ne sont jamais présentées comme preuve d'inférence ou de qualité.
- Boutons Vérifier les moteurs du téléphone / Copier le diagnostic dans les réglages existants. Diagnostic sans photo, prompt ni clé.
- L'absence d'un moteur, une clé MNN incorrecte ou une configuration ambiguë bloquent avant la réservation d'une tentative d'inférence et conservent les dessins.
- Réduction du transfert de pixels par demande PNG au moteur Local Dream, avec lecture contrôlée du PNG et conservation du format RGB brut historique. Dimensions vérifiées avant décompression.
- La clé MNN est envoyée uniquement aux routes vision, jamais à Local Dream ; aucune redirection HTTP des données locales n'est suivie.
- La provenance des revues précédentes reste stable à la réouverture. Le budget de correction distingue les modèles actifs sans effacer le journal technique.
- Tests HTTP réels sur boucle locale avec moteurs simulés : six cas de connexion, zéro POST lors du diagnostic ; parcours local complet simulé avec reprise et correction ciblée. Aucun nouveau modèle réel ni test physique Xiaomi revendiqué.

Limites : MNN Chat, Local Dream et leurs poids ne sont pas intégrés à cet APK. Ils doivent être installés/chargés sur le téléphone. Le CPU SD1.5 est le profil initial ; les accélérations Qualcomm/DiT ne sont pas supposées disponibles sur MediaTek. Fidélité, mouvement, vitesse et mémoire des modèles réels restent à mesurer. La V56 n'est pas une validation de qualité universelle équivalente à ChatGPT.
