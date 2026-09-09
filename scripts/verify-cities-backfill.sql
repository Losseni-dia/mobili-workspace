-- Script de VÉRIFICATION uniquement (aucune écriture) — à coller dans la session psql staging
-- pour confirmer que les migrations V54/V55 ont bien tourné et que le backfill des villes a
-- fonctionné (voir V55__backfill_cities_from_existing_trips.sql).

-- 1) Les migrations V54 et V55 sont bien enregistrées comme appliquées.
SELECT version, description, success, installed_on
FROM flyway_schema_history
WHERE version IN ('54', '55')
ORDER BY version;

-- 2) Compte total de villes en base, et combien ont un pays / des coordonnées / sont vérifiées.
SELECT
    COUNT(*) AS total_villes,
    COUNT(*) FILTER (WHERE country_id IS NOT NULL) AS avec_pays,
    COUNT(*) FILTER (WHERE latitude IS NOT NULL) AS avec_coordonnees,
    COUNT(*) FILTER (WHERE verified) AS verifiees
FROM cities;

-- 3) Abidjan (le cas signalé) — doit maintenant exister, avec ses coordonnées reprises de
-- trip_stops si le script scripts/seed-trip-stop-coordinates.sql avait déjà été exécuté.
SELECT id, name, country_id, latitude, longitude, verified
FROM cities
WHERE name ILIKE 'abidjan';

-- 4) Quelques autres grandes villes attendues (Bouaké, Yamoussoukro, Daloa, Korhogo...).
SELECT id, name, country_id, latitude, longitude, verified
FROM cities
WHERE name ILIKE ANY (ARRAY['bouaké', 'bouake', 'yamoussoukro', 'daloa', 'korhogo', 'man', 'gagnoa'])
ORDER BY name;

-- 5) Villes non vérifiées en attente sur l'écran admin Pays & Villes (pour info).
SELECT COUNT(*) AS villes_non_verifiees FROM cities WHERE NOT verified;
