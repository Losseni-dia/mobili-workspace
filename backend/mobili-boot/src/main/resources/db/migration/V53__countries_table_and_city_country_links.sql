-- Chantier Pays/Villes : table Country reelle (remplace la duplication de la liste des ~98 pays
-- entre admin-geocoding.ts (Angular) et admin_geocoding_page.dart (mobilipro) par une source
-- unique en base), City reliee a un pays + coordonnees + statut de verification, et Partner/
-- Station rattaches. Voir CityLookupService (flux "ville introuvable, on soumet quand meme").
--
-- IMPORTANT : les anciennes colonnes cities.country (toujours 'CI' en dur, jamais vraiment
-- utilisee) et stations.city (texte libre) sont laissees en place, non supprimees — plus sur,
-- reversible, et ddl-auto=validate (staging/prod) ne se plaint jamais d'une colonne en base non
-- mappee par une entite. A retirer dans une migration ulterieure une fois confirme que
-- country_id/city_id sont bien utilises partout.

CREATE TABLE IF NOT EXISTS countries (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    iso_code VARCHAR(2) NOT NULL,
    continent VARCHAR(20),
    CONSTRAINT uq_country_name UNIQUE (name),
    CONSTRAINT uq_country_iso_code UNIQUE (iso_code)
);

-- Seed unique des ~98 pays Afrique + Europe deja curates cote ecrans de geocodage (Angular +
-- mobilipro) — evite de re-taper la liste a la main.
INSERT INTO countries (name, iso_code, continent) VALUES
    ('Algérie', 'DZ', 'Afrique'),
    ('Angola', 'AO', 'Afrique'),
    ('Bénin', 'BJ', 'Afrique'),
    ('Botswana', 'BW', 'Afrique'),
    ('Burkina Faso', 'BF', 'Afrique'),
    ('Burundi', 'BI', 'Afrique'),
    ('Cap-Vert', 'CV', 'Afrique'),
    ('Cameroun', 'CM', 'Afrique'),
    ('République centrafricaine', 'CF', 'Afrique'),
    ('Tchad', 'TD', 'Afrique'),
    ('Comores', 'KM', 'Afrique'),
    ('Congo', 'CG', 'Afrique'),
    ('RD Congo', 'CD', 'Afrique'),
    ('Djibouti', 'DJ', 'Afrique'),
    ('Égypte', 'EG', 'Afrique'),
    ('Guinée équatoriale', 'GQ', 'Afrique'),
    ('Érythrée', 'ER', 'Afrique'),
    ('Eswatini', 'SZ', 'Afrique'),
    ('Éthiopie', 'ET', 'Afrique'),
    ('Gabon', 'GA', 'Afrique'),
    ('Gambie', 'GM', 'Afrique'),
    ('Ghana', 'GH', 'Afrique'),
    ('Guinée', 'GN', 'Afrique'),
    ('Guinée-Bissau', 'GW', 'Afrique'),
    ('Côte d''Ivoire', 'CI', 'Afrique'),
    ('Kenya', 'KE', 'Afrique'),
    ('Lesotho', 'LS', 'Afrique'),
    ('Liberia', 'LR', 'Afrique'),
    ('Libye', 'LY', 'Afrique'),
    ('Madagascar', 'MG', 'Afrique'),
    ('Malawi', 'MW', 'Afrique'),
    ('Mali', 'ML', 'Afrique'),
    ('Mauritanie', 'MR', 'Afrique'),
    ('Maurice', 'MU', 'Afrique'),
    ('Maroc', 'MA', 'Afrique'),
    ('Mozambique', 'MZ', 'Afrique'),
    ('Namibie', 'NA', 'Afrique'),
    ('Niger', 'NE', 'Afrique'),
    ('Nigeria', 'NG', 'Afrique'),
    ('Rwanda', 'RW', 'Afrique'),
    ('Sao Tomé-et-Principe', 'ST', 'Afrique'),
    ('Sénégal', 'SN', 'Afrique'),
    ('Seychelles', 'SC', 'Afrique'),
    ('Sierra Leone', 'SL', 'Afrique'),
    ('Somalie', 'SO', 'Afrique'),
    ('Afrique du Sud', 'ZA', 'Afrique'),
    ('Soudan du Sud', 'SS', 'Afrique'),
    ('Soudan', 'SD', 'Afrique'),
    ('Tanzanie', 'TZ', 'Afrique'),
    ('Togo', 'TG', 'Afrique'),
    ('Tunisie', 'TN', 'Afrique'),
    ('Ouganda', 'UG', 'Afrique'),
    ('Zambie', 'ZM', 'Afrique'),
    ('Zimbabwe', 'ZW', 'Afrique'),
    ('Albanie', 'AL', 'Europe'),
    ('Andorre', 'AD', 'Europe'),
    ('Autriche', 'AT', 'Europe'),
    ('Biélorussie', 'BY', 'Europe'),
    ('Belgique', 'BE', 'Europe'),
    ('Bosnie-Herzégovine', 'BA', 'Europe'),
    ('Bulgarie', 'BG', 'Europe'),
    ('Croatie', 'HR', 'Europe'),
    ('Chypre', 'CY', 'Europe'),
    ('Tchéquie', 'CZ', 'Europe'),
    ('Danemark', 'DK', 'Europe'),
    ('Estonie', 'EE', 'Europe'),
    ('Finlande', 'FI', 'Europe'),
    ('France', 'FR', 'Europe'),
    ('Allemagne', 'DE', 'Europe'),
    ('Grèce', 'GR', 'Europe'),
    ('Hongrie', 'HU', 'Europe'),
    ('Islande', 'IS', 'Europe'),
    ('Irlande', 'IE', 'Europe'),
    ('Italie', 'IT', 'Europe'),
    ('Kosovo', 'XK', 'Europe'),
    ('Lettonie', 'LV', 'Europe'),
    ('Liechtenstein', 'LI', 'Europe'),
    ('Lituanie', 'LT', 'Europe'),
    ('Luxembourg', 'LU', 'Europe'),
    ('Malte', 'MT', 'Europe'),
    ('Moldavie', 'MD', 'Europe'),
    ('Monaco', 'MC', 'Europe'),
    ('Monténégro', 'ME', 'Europe'),
    ('Pays-Bas', 'NL', 'Europe'),
    ('Macédoine du Nord', 'MK', 'Europe'),
    ('Norvège', 'NO', 'Europe'),
    ('Pologne', 'PL', 'Europe'),
    ('Portugal', 'PT', 'Europe'),
    ('Roumanie', 'RO', 'Europe'),
    ('Russie', 'RU', 'Europe'),
    ('Saint-Marin', 'SM', 'Europe'),
    ('Serbie', 'RS', 'Europe'),
    ('Slovaquie', 'SK', 'Europe'),
    ('Slovénie', 'SI', 'Europe'),
    ('Espagne', 'ES', 'Europe'),
    ('Suède', 'SE', 'Europe'),
    ('Suisse', 'CH', 'Europe'),
    ('Ukraine', 'UA', 'Europe'),
    ('Royaume-Uni', 'GB', 'Europe'),
    ('Vatican', 'VA', 'Europe')
ON CONFLICT (iso_code) DO NOTHING;

-- cities : rattachement pays + coordonnees + statut de verification.
ALTER TABLE cities ADD COLUMN IF NOT EXISTS country_id BIGINT REFERENCES countries (id);
ALTER TABLE cities ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE cities ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
-- DEFAULT TRUE ne s'applique qu'au backfill des lignes existantes (deja utilisees en production,
-- considerees fiables) — les nouvelles lignes creees via CityLookupService passent explicitement
-- verified=false, Hibernate l'ecrit toujours lui-meme a l'insert.
ALTER TABLE cities ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT TRUE;

-- Backfill : toutes les villes existantes rattachees a la Cote d'Ivoire par defaut (decision
-- actee avec l'utilisateur, coherent avec l'ancien defaut 'CI' en dur sur cities.country) — les
-- cas particuliers (villes europeennes des tests de tracking, etc.) se corrigent ensuite a la
-- main via l'ecran admin Pays & Villes.
UPDATE cities
SET country_id = (SELECT id FROM countries WHERE iso_code = 'CI')
WHERE country_id IS NULL;

-- partners : pays de la societe, meme backfill par defaut.
ALTER TABLE partners ADD COLUMN IF NOT EXISTS country_id BIGINT REFERENCES countries (id);
UPDATE partners
SET country_id = (SELECT id FROM countries WHERE iso_code = 'CI')
WHERE country_id IS NULL;

-- stations : ville reelle (FK) au lieu du texte libre stations.city. Assure d'abord une ligne
-- 'cities' pour chaque ville de gare deja utilisee (rattachee CI par defaut), puis relie.
ALTER TABLE stations ADD COLUMN IF NOT EXISTS city_id BIGINT REFERENCES cities (id);

INSERT INTO cities (name, country_id, verified)
SELECT DISTINCT LOWER(TRIM(s.city)), (SELECT id FROM countries WHERE iso_code = 'CI'), TRUE
FROM stations s
WHERE s.city IS NOT NULL
    AND TRIM(s.city) <> ''
ON CONFLICT (name) DO NOTHING;

UPDATE stations s
SET city_id = c.id
FROM cities c
WHERE LOWER(TRIM(s.city)) = c.name
    AND s.city_id IS NULL;
