ALTER TABLE stations ADD COLUMN password VARCHAR(255);

ALTER TABLE stations ADD CONSTRAINT uk_stations_code UNIQUE (code);