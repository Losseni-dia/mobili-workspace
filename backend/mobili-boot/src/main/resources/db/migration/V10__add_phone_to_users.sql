ALTER TABLE users
ALTER COLUMN email
DROP NOT NULL,
ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

-- Index unique sur phone (non null seulement)
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON users (phone)
WHERE
    phone IS NOT NULL;