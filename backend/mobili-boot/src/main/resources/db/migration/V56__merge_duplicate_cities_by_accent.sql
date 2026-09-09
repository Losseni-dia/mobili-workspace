-- Corrige un doublon introduit par V55 : le dédoublonnage y comparait les noms via LOWER()
-- uniquement, qui ne normalise pas les accents — "Bouaké" et "bouake" (ou "Séguéla"/"Seguela",
-- "Duékoué"/"Duekoue", etc.) sont donc passés pour deux villes différentes et ont chacune leur
-- ligne dans "cities" (constaté en base staging : bouake id 25 et bouaké id 18 coexistent).
--
-- Cette migration regroupe les villes par nom normalisé (minuscule + accents retirés), garde une
-- seule ligne "canonique" par groupe (priorité : vérifiée > coordonnées connues > id le plus
-- petit), repointe les références (stations.city_id) vers cette ligne canonique, purge le cache
-- de durées (city_leg_durations) pour les villes fusionnées — recalculé automatiquement au
-- prochain trajet concerné, aucune perte fonctionnelle — puis supprime les doublons.

CREATE OR REPLACE FUNCTION _tmp_normalize_city_name(text) RETURNS text AS $$
    SELECT translate(lower($1), 'àâäéèêëïîôöùûüÿçñ', 'aaaeeeeiioouuuycn');
$$ LANGUAGE SQL IMMUTABLE;

CREATE TEMP TABLE _city_merge AS
WITH grouped AS (
    SELECT
        id,
        _tmp_normalize_city_name(name) AS norm_name,
        ROW_NUMBER() OVER (
            PARTITION BY _tmp_normalize_city_name(name)
            ORDER BY verified DESC, (latitude IS NOT NULL) DESC, id ASC
        ) AS rn
    FROM cities
)
SELECT dup.id AS duplicate_id, canon.id AS canonical_id
FROM grouped dup
JOIN grouped canon ON canon.norm_name = dup.norm_name AND canon.rn = 1
WHERE dup.rn > 1;

-- Cache de durées : purge plutôt que fusion (évite tout conflit avec la contrainte unique
-- (from_city_id, to_city_id) si les deux extrémités d'un tronçon fusionnent vers la même paire
-- canonique) — recalculé au prochain enregistrement du trajet concerné, coût négligeable.
DELETE FROM city_leg_durations
WHERE from_city_id IN (SELECT duplicate_id FROM _city_merge)
   OR to_city_id IN (SELECT duplicate_id FROM _city_merge);

UPDATE stations s
SET city_id = m.canonical_id
FROM _city_merge m
WHERE s.city_id = m.duplicate_id;

DELETE FROM cities c
WHERE c.id IN (SELECT duplicate_id FROM _city_merge);

DROP FUNCTION _tmp_normalize_city_name(text);
