# KARMA ONE V54 — recette finale Xiaomi 14T Pro
Statut : procédure préparée, PAS exécutée sur le téléphone. Aucun accès physique ou ADB au Xiaomi dans cette session.

## Installation
Télécharger l'archive de l'artefact KARMA_ONE_V54_ARM64 du build réussi, extraire l'APK puis installer la mise à jour. Conserver les projets existants ; ne pas désinstaller pour contourner une erreur de signature. Le build comprend SHA256SUMS.txt et les métadonnées du paquet.

## Parcours à contrôler
1. Ouvrir le studio, choisir une image depuis Photos/Galerie, vérifier orientation et affichage. L'import seul ne doit envoyer aucune image.
2. Pour un premier essai, utiliser une image synthétique sans donnée privée et une histoire simple : « La banane vivante se baisse puis se redresse ; conserver les membres et le fond ». Appuyer sur création après lecture de l'information d'envoi au fournisseur.
3. Vérifier un résultat réel d'analyse, puis des dessins distincts correspondant aux actions. Une image déplacée ou déformée, une analyse en erreur, ou des poses identiques ne valident pas le générateur.
4. Avant Garder sur chaque dessin et confirmation globale, Exporter doit rester bloqué. Refuser un dessin doit bloquer à nouveau.
5. Refaire un dessin : vérifier l'amélioration demandée, la conservation des voisins et la nécessité de garder à nouveau le dessin corrigé.
6. Fermer puis reprendre : dessins conservés, nouvelle confirmation globale requise. Modifier l'histoire ou le style doit invalider l'accord.
7. Après validation complète, exporter le MP4, ouvrir le fichier dans le lecteur Android puis dans CapCut ; tester début, milieu, fin, et partage.
8. Contrôler le MP4 exporté avec ffprobe : codec h264, FPS 30, durée attendue, nombre d'images égal à durée × 30 pour une durée entière. Décoder le fichier complet avec ffmpeg -v error -xerror -i export.mp4 -f null -. Le contrôle CI avec ffmpeg ne valide pas MediaCodec sur le Xiaomi.
9. Répéter ensuite avec un animal, un véhicule, plusieurs sujets et une transformation. Le premier cas ne valide pas l'universalité.

## Preuves à conserver localement
Version Android et application, histoire exacte, planche, journal de session, heure du test, MP4 et résultat ffprobe. Ne publier aucune photo privée ni sortie dérivée sur GitHub.

## Critères de non-validation
Échec réseau, analyse indisponible, fidélité non vérifiée, dessins manquants, mouvements non redessinés, export avant accord, plantage, vidéo illisible ou durée incorrecte. Ne pas présenter MediaPipe, le redessin IA ni l'encodage matériel comme validés sans leurs exécutions réelles.
