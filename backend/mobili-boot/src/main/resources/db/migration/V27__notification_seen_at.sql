ALTER TABLE mobili_inbox_notifications ADD COLUMN seen_at TIMESTAMP;

ALTER TABLE stations ADD COLUMN fcm_token VARCHAR(500);