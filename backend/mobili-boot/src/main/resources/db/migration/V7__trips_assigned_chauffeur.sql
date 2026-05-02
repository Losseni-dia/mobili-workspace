-- Chauffeur société affecté à un trajet (dispatch par la gare ou le partenaire).
ALTER TABLE trips ADD COLUMN IF NOT EXISTS assigned_chauffeur_id BIGINT NULL REFERENCES users (id);

CREATE INDEX IF NOT EXISTS idx_trips_assigned_chauffeur ON trips (assigned_chauffeur_id);
