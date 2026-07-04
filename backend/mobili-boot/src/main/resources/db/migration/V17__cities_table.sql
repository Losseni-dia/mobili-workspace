-- Table des villes persistées automatiquement
CREATE TABLE IF NOT EXISTS cities (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    country VARCHAR(50) DEFAULT 'CI',
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT uq_city_name UNIQUE (name)
);

-- Alimenter depuis les trajets existants
INSERT INTO
    cities (name)
SELECT DISTINCT
    LOWER(TRIM(departure_city))
FROM trips
WHERE
    departure_city IS NOT NULL
    AND TRIM(departure_city) != '' ON CONFLICT (name) DO NOTHING;

INSERT INTO
    cities (name)
SELECT DISTINCT
    LOWER(TRIM(arrival_city))
FROM trips
WHERE
    arrival_city IS NOT NULL
    AND TRIM(arrival_city) != '' ON CONFLICT (name) DO NOTHING;