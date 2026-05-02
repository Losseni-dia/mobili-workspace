-- À exécuter une fois sur une base Mobili déjà existante (sans réinitialiser le volume Postgres).
-- Remplacez le mot de passe si besoin ; alignez POSTGRES_DATASOURCE_PASSWORD dans .env à la racine.
--
-- Exemple :
--   docker compose exec -T postgres psql -U mobili -d mobili -v ON_ERROR_STOP=1 -f deploy/postgres/manual-grafana-readonly.sql
-- (depuis la racine du dépôt ; sous Windows Git Bash adapter le chemin.)

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grafana_ro') THEN
    CREATE ROLE grafana_ro WITH LOGIN PASSWORD 'grafana_ro_dev';
  END IF;
END
$$;

GRANT CONNECT ON DATABASE mobili TO grafana_ro;

GRANT USAGE ON SCHEMA public TO grafana_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE mobili IN SCHEMA public GRANT SELECT ON TABLES TO grafana_ro;
