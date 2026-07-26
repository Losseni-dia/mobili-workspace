ALTER TABLE mobili_inbox_notifications
ADD COLUMN partner_id BIGINT REFERENCES partners (id);