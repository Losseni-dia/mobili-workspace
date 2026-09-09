-- Backfill de "cities" depuis les trajets déjà en base — nécessaire car TripService.persistCity()
-- n'était appelé QUE pour les trajets covoiturage solo (createCovoiturageSoloTrip), jamais pour
-- les trajets société/gare classiques (TripService.save(), l'immense majorité du catalogue) :
-- des villes aussi centrales qu'Abidjan n'existaient donc pas dans "cities" avant cette
-- migration, rendant l'autocomplétion (station-list, add-trip/trip-edit, chantiers A6/B2)
-- inutilisable pour elles — toujours "ville introuvable" alors que la ville est évidemment déjà
-- utilisée partout dans le catalogue.
--
-- Décision "Côte d'Ivoire par défaut" reprise telle quelle de V53 (même logique, mêmes
-- exceptions à corriger ensuite à la main via l'écran admin Pays & Villes pour les quelques
-- villes hors CI déjà croisées dans les tests — Accra, Bamako, Conakry, Dakar...).

-- 1) Toutes les villes distinctes utilisées dans les trajets (départ, arrivée, étapes CSV) —
-- comparaison insensible à la casse pour ne jamais dupliquer une ville déjà backfillée par V53
-- (stations.city, alors insérée en minuscules).
WITH trip_city_names AS (
    SELECT DISTINCT TRIM(name) AS name FROM (
        SELECT departure_city AS name FROM trips
        WHERE departure_city IS NOT NULL AND TRIM(departure_city) <> ''
        UNION ALL
        SELECT arrival_city AS name FROM trips
        WHERE arrival_city IS NOT NULL AND TRIM(arrival_city) <> ''
        UNION ALL
        SELECT TRIM(unnest(string_to_array(stops_cities, ','))) AS name
        FROM trips
        WHERE stops_cities IS NOT NULL AND TRIM(stops_cities) <> ''
    ) all_names
    WHERE TRIM(name) <> ''
)
INSERT INTO cities (name, country_id, verified)
SELECT tcn.name, (SELECT id FROM countries WHERE iso_code = 'CI'), FALSE
FROM trip_city_names tcn
WHERE NOT EXISTS (
    SELECT 1 FROM cities c WHERE LOWER(c.name) = LOWER(tcn.name)
);

-- 2) Coordonnées déjà géocodées manuellement (trip_stops.latitude/longitude, scripts ponctuels
-- scripts/geocoded-cities.sql et scripts/seed-trip-stop-coordinates.sql, exécutés avant
-- l'existence de la table cities) — recopiées sur la ville correspondante et marquées vérifiées
-- (un humain a déjà relu/exécuté ces coordonnées, voir en-tête de ces scripts).
UPDATE cities c
SET latitude = ts.latitude, longitude = ts.longitude, verified = TRUE
FROM (
    SELECT DISTINCT ON (LOWER(TRIM(city_label))) TRIM(city_label) AS city_label, latitude, longitude
    FROM trip_stops
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL
    ORDER BY LOWER(TRIM(city_label)), id
) ts
WHERE LOWER(c.name) = LOWER(ts.city_label)
    AND c.latitude IS NULL;
