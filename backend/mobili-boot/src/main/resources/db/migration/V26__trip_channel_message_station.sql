ALTER TABLE trip_channel_messages
ADD COLUMN station_id BIGINT REFERENCES stations (id);