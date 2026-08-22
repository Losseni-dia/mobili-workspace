-- La contrainte trips_status_check (existante en base de prod, hors suivi Flyway jusqu'ici —
-- absente de toute migration versionnée dans ce dépôt) n'autorisait que les statuts
-- PROGRAMMÉ/EN_COURS/TERMINÉ/ANNULÉ. Le nouveau statut DRAFT (sécurité Enregistrer/Publier à
-- la création d'un trajet — TripStatus.java) était donc rejeté en base à l'insertion, avec un
-- message générique "Cette ressource existe déjà" (409 MOB-004) masquant la vraie cause.
-- Même pattern défensif que trips_vehicle_type_check (V2__schema_baseline_idempotent.sql).
DO $chk$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = current_schema() AND table_name = 'trips') THEN
    ALTER TABLE trips DROP CONSTRAINT IF EXISTS trips_status_check;
    ALTER TABLE trips
      ADD CONSTRAINT trips_status_check
      CHECK (status IN ('DRAFT', 'PROGRAMMÉ', 'EN_COURS', 'TERMINÉ', 'ANNULÉ'));
  END IF;
END
$chk$;
