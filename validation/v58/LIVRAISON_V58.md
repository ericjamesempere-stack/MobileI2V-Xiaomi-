# KARMA ONE V58 — livraison de correction et limites vérifiées

Date : 17 novembre 2026 (France). Cette livraison est un **candidat Android de correction**, pas une application universelle déclarée définitive.

## Identification exacte

- Base conservée : `8176fb4dd6aeafa8f07d3a63ffdc47f61677187c` (V57).
- Commit applicatif compilé et testé : `457ec74fb88969216c476efa6ed59e7f60cce9f7`.
- Version : `1.5.8 (V58 Android)`, versionCode `13`, paquet `com.ericjamesempere.mobilei2v`, ARM64.
- APK : `KARMA_ONE_V58_ANDROID_20261117_ARM64.apk`, 87 944 416 octets.
- SHA256 APK : `979ce471fa0c016598a9f4b55354bf767883b65069bb4b9e30ef3e8209834a5d`.
- Certificat SHA256 : `5fe844e7ae98d51d5464f1e3a7d58e218aeade4c11b8fe4a1c5ed5e45d9663ef`, identique à la V57 de référence signée avec la clé V55.
- [Workflow réussi](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44185172259).
- [Artefact GitHub du commit testé](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/actions/runs/44185172259/artifacts/14373009879), conservé jusqu'au 17 décembre 2026, connexion GitHub éventuellement nécessaire.
- [Code exact](https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/tree/457ec74fb88969216c476efa6ed59e7f60cce9f7).

Le rapport est ajouté après compilation ; il ne modifie pas le code de cet APK.

## Bug A — import photo

Défaut de robustesse constaté : résultat V57 uniquement en mémoire dans le plugin, perdu si son instance est recréée ; délai sans identification de l'étape. La cause exacte du blocage observé sur le Xiaomi reste non confirmée faute de journal de cet appareil. Le callback onMainActivityResult existe et est transmis par Godot 4.5.2.

Correction : récepteur Android interne non exporté dans la même application et le même parcours d'import. Résultat privé persistant, identifiant de sélection invalidé après consommation, rejet des travaux annulés/périmés, récupération après recréation. Décodage Android et conversion PNG hors thread UI, taille bornée à 4096 px, gestion des URI accordées par le sélecteur, délai de sécurité natif. Les diagnostics distinguent sélection, décodage, sauvegarde et absence de résultat. Références et manifests de projets distincts ; retour à un ancien projet depuis Mes images enregistrées.

JPG/PNG/WebP utilisent le décodeur Android. HEIC n'est accepté que si le décodeur du téléphone le prend en charge. Cette compatibilité n'a pas été démontrée matériellement ici.

## Bug B — génération

V57 ne contient ni MNN Chat, ni Local Dream, ni leurs poids de modèles. HTTP 0 ne permet pas de savoir si l'application est absente, le service arrêté ou le modèle non chargé.

V58 ajoute détection bornée des paquets Android concernés et diagnostic HTTP/réseau/endpoint. Le choix local/distant est accessible dès la première étape, avant la création texte → image. Aucune bascule en ligne automatique n'est ajoutée.

**Essai réel distant : refus pour quota ZeroGPU épuisé.** Le connecteur existant a envoyé seulement une description de banane sur une table, sans photo personnelle. Aucune image n'a été obtenue ; aucune inférence réussie, planche IA réelle ou fidélité universelle n'est revendiquée. L'installation, les modèles et les services locaux du Xiaomi ne peuvent pas être confirmés sans accès au téléphone.

## Résultats

| Niveau | Résultat vérifié | Limite |
|---|---|---|
| A — code | Compilation Java/AAR, 6 tests Robolectric, scripts Godot 4.5.2, démarrage, APK ARM64, signature, manifeste et DEX : réussis dans le workflow | Robolectric simule Android |
| B — fonctions | Véritable écran Godot : WebP réel, aperçu, sauvegarde, réouverture, récupération, annulation, doublons, imports successifs, reprise des projets ; contrôles de validation et régénération ciblée testés | IA simulée dans les tests d'intégration ; galerie Android matérielle non testée |
| C — IA | Tentative réelle distante exécutée et refusée pour quota | Aucune inférence réussie ; moteur local non testé sur Xiaomi |
| D — vidéo | Vrai MP4 FFmpeg H.264, 96×160, 30 FPS, 150 images, 5 s, décodage complet sans erreur | Dessins de fixture et MediaCodec simulés ; ce film technique ne prouve pas une animation IA |
| E — téléphone | Protocole ci-dessous prêt | Aucun accès physique/ADB au Xiaomi, donc non validé |

Une régression sur les anciens résultats a été détectée par la suite complète puis corrigée ; les candidats en échec n'ont pas été livrés. Le workflow final a réussi tous ses contrôles.

## Installation sans perdre les projets

1. Télécharger l'APK V58 et l'ouvrir sur le Xiaomi.
2. Installer **par-dessus la V57 de référence**, sans désinstaller l'application.
3. Si Android refuse la signature, conserver l'application existante et son contenu. Ne pas désinstaller pour forcer. D'anciens candidats V56/V57 ont pu utiliser un certificat différent.

## Test indispensable sur le Xiaomi

1. Choisir une photo JPG locale ; vérifier l'aperçu et les dimensions.
2. Fermer puis rouvrir KARMA ONE ; vérifier que la référence reste disponible.
3. Tester annuler puis importer une seconde photo ; retrouver le premier projet dans Mes images enregistrées.
4. Dans les options, Vérifier les moteurs du téléphone puis Copier le diagnostic. Celui-ci ne contient ni photo ni jeton.
5. Si un moteur est réellement opérationnel : créer une image, demander une courte action, inspecter chaque dessin, tester Refuser/Refaire, confirmer la planche, exporter et lire le MP4.

Le choix distant transfère les images et descriptions aux services annoncés seulement quand ce mode est choisi et une génération demandée. Quotas et disponibilité variables ; aucun abonnement automatique et aucune promesse d'illimité.

## Blocage restant

La suite autonome s'arrête ici sur une dépendance extérieure précisément identifiée : pas de moteur/modèle local confirmé sur le téléphone et refus de quota du moteur distant essayé. La validation finale exige un essai d'import sur Xiaomi puis une véritable génération disponible. Aucun résultat simulé ne remplace ces preuves.

Le détail des correctifs et les journaux de tests sont dans [RESULTATS_V58.md](RESULTATS_V58.md) et ce dossier. Les modules et fonctionnalités antérieurs n'ont pas été supprimés.
