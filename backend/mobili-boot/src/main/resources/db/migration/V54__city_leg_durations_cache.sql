-- Cache des durées de trajet (Mapbox/Google Directions) entre paires de villes — évite de
-- refacturer un appel Directions à chaque création/modification de trajet pour un tronçon déjà
-- calculé (voir TripStopSyncService.legDurationMinutes / CityLegDuration). Sans cette table,
-- chaque enregistrement de trajet avec N arrêts géocodés déclenchait jusqu'à N-1 appels API
-- payants ; avec elle, une paire de villes n'est facturée qu'une fois (rafraîchie après 180 jours
-- côté application, voir TripStopSyncService.STALE_AFTER).

CREATE TABLE IF NOT EXISTS city_leg_durations (
    id BIGSERIAL PRIMARY KEY,
    from_city_id BIGINT NOT NULL REFERENCES cities (id),
    to_city_id BIGINT NOT NULL REFERENCES cities (id),
    duration_seconds BIGINT NOT NULL,
    distance_meters DOUBLE PRECISION,
    computed_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_city_leg_duration_pair UNIQUE (from_city_id, to_city_id)
);

CREATE INDEX IF NOT EXISTS idx_city_leg_durations_from_to
    ON city_leg_durations (from_city_id, to_city_id);
