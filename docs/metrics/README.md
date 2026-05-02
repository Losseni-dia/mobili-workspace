# Métriques & observabilité (Mobili API)

Documentation pour **Prometheus**, **Grafana** et les endpoints **Spring Boot Actuator** exposés en développement.

| Document | Contenu |
|----------|---------|
| [guide-utilisation.md](guide-utilisation.md) | **Manuel** : prérequis, démarrage, URLs, PromQL, dashboards technique + métier SQL, Postgres (`host.docker.internal`, UID `mobili-postgres`), vérif des variables dans le conteneur, Explore SQL, dépannage |

Configurer la stack : fichier racine [`docker-compose.yml`](../../docker-compose.yml) (profil Compose `metrics`), fichier Prometheus [`deploy/prometheus/prometheus.yml`](../../deploy/prometheus/prometheus.yml).
