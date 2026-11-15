# Cartoon Studio — véritable moteur génératif

Le moteur **existe dans le dépôt** : `ai_redraw/pose.py` exécute Stable Diffusion 1.5 + ControlNet OpenPose avec les poids des modèles open source. `ai_redraw/godot_adapter.py` expose `POST /generate` au format JSON attendu par Godot. Ce n'est **pas** un moteur autonome intégré dans l'APK Android.

## Démarrage sur une machine avec GPU NVIDIA

Prérequis : Docker, Docker Compose, pilotes NVIDIA et NVIDIA Container Toolkit compatibles, mémoire GPU suffisante, espace disque pour les poids des modèles, connexion Internet pour leur premier téléchargement.

Depuis la racine du dépôt :

```bash
docker compose -f docker-compose.redraw.yml up --build
curl http://127.0.0.1:8765/health
```

Le premier appel `POST /generate` télécharge les poids puis charge le modèle. Les poids sont conservés dans le volume Docker `model-cache`. Un `/health` réussi **ne garantit pas** que les modèles sont chargés ou que l'inférence fonctionne.

Pour lancer un test avec **vraie inférence, sans simulation** :

```bash
docker compose -f docker-compose.redraw.yml exec -e REDRAW_REAL_TEST=1 cartoon-redraw \
  python -m pytest -q ai_redraw/test_real_inference.py
```

Le Dockerfile n'installe pas pytest par défaut : pour ce test, l'installer dans le conteneur (`pip install pytest httpx`) ou utiliser un environnement Python doté des dépendances complètes. L'exécution du test exige réellement les poids et les ressources nécessaires.

## Connexion du Xiaomi

Le port Docker est limité à `127.0.0.1` pour ne pas exposer sans authentification une API consommant beaucoup de ressources. Pour l'application Android, configurer un **point d'accès HTTPS sécurisé** vers le serveur (reverse proxy ou tunnel privé), puis saisir son URL complète terminée par `/generate` dans l'application. Ne jamais exposer le port public sans authentification, contrôle de débit et limites de charge.

## Limites réelles

- **Génération réelle** : le modèle calcule des pixels nouveaux à partir d'une image de référence et d'une pose.
- **Identité du personnage** : pas de garantie d'identité parfaite. Le visage et les vêtements peuvent varier.
- **Fluidité** : des images successives sont calculées séparément ; pas encore de cohérence temporelle garantie.
- **Android hors ligne** : non disponible. Le Xiaomi ne dispose pas ici d'un runtime et de poids compatibles démontrés pour ce pipeline.
- **Gratuité** : les modèles sont ouverts, mais le calcul, l'électricité ou un éventuel hébergement GPU ne sont pas gratuits par nature.
- **Statut** : le test d'inférence réelle doit être exécuté sur une machine GPU ; la CI actuelle ne teste que les contrats et la compilation.
