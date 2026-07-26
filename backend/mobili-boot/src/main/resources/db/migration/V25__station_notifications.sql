ALTER TABLE mobili_inbox_notifications
ALTER COLUMN user_id
DROP NOT NULL;

ALTER TABLE mobili_inbox_notifications
ADD COLUMN station_id BIGINT REFERENCES stations (id);