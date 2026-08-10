-- Distingue "destinataire" (user, déjà existant) de "sujet" (subject_user) : une alerte
-- KYC covoiturage envoyée aux admins concerne un chauffeur précis, différent de chaque
-- admin qui la reçoit. Permet d'ouvrir directement la fiche du chauffeur concerné.
ALTER TABLE mobili_inbox_notifications ADD COLUMN subject_user_id BIGINT REFERENCES users(id);
CREATE INDEX idx_mobili_inbox_notifications_subject_user_id ON mobili_inbox_notifications(subject_user_id);
