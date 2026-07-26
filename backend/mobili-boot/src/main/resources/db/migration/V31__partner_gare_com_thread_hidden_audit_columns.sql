ALTER TABLE partner_gare_com_thread_hidden
ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT now();

ALTER TABLE partner_gare_com_thread_hidden
ADD COLUMN updated_at TIMESTAMP;