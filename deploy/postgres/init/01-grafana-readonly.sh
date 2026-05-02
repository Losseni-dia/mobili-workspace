#!/usr/bin/env bash
# Premier démarrage du volume Postgres uniquement (docker-entrypoint-initdb.d).
# Crée grafana_ro + GRANT SELECT pour les dashboards Grafana « business ».
set -euo pipefail
PW="${GRAFANA_RO_PASSWORD:-grafana_ro_dev}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grafana_ro') THEN
    EXECUTE format('CREATE ROLE grafana_ro WITH LOGIN PASSWORD %L', '${PW}');
  END IF;
END
\$\$;

GRANT CONNECT ON DATABASE "${POSTGRES_DB}" TO grafana_ro;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
GRANT USAGE ON SCHEMA public TO grafana_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE "${POSTGRES_USER}" IN SCHEMA public GRANT SELECT ON TABLES TO grafana_ro;
EOSQL
