-- Gare d’exercice / affectation pour chauffeur salarié (même compagnie). distinct de station_id (compte gare).
ALTER TABLE users ADD COLUMN IF NOT EXISTS chauffeur_affiliation_station_id bigint;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_users_chauffeur_affiliation_station'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT fk_users_chauffeur_affiliation_station
      FOREIGN KEY (chauffeur_affiliation_station_id) REFERENCES stations (id) ON DELETE SET NULL;
  END IF;
END $$;
