ALTER TABLE partner_gare_com_messages
ADD COLUMN station_id BIGINT REFERENCES stations (id);