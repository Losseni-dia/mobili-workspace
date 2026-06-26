ALTER TABLE admin_com_threads
ADD COLUMN type VARCHAR(30) NOT NULL DEFAULT 'PARTNER';

-- PARTNER  = admin ↔ dirigeant compagnie
-- COVOITURAGE = admin ↔ chauffeur covoiturage solo
-- SUPPORT  = admin ↔ client passager
COMMENT ON COLUMN admin_com_threads.type IS 'PARTNER | COVOITURAGE | SUPPORT';