ALTER TABLE partners
ADD COLUMN approval_status VARCHAR(20) NOT NULL DEFAULT 'APPROVED';

UPDATE partners
SET
    approval_status = 'APPROVED'
WHERE
    enabled = true;