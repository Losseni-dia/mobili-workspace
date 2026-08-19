ALTER TABLE claims
    ADD COLUMN attachment_path VARCHAR(500),
    ADD COLUMN attachment_original_name VARCHAR(255),
    ADD COLUMN attachment_content_type VARCHAR(100);

ALTER TABLE admin_com_messages
    ADD COLUMN attachment_path VARCHAR(500),
    ADD COLUMN attachment_original_name VARCHAR(255),
    ADD COLUMN attachment_content_type VARCHAR(100);
