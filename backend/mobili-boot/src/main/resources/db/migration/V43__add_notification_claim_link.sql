-- Lien réel vers la réclamation concernée, même pattern que trip_id/booking_id/
-- partner_id sur cette table : permet au client d'ouvrir directement la bonne
-- réclamation depuis la notification plutôt que la liste entière.
ALTER TABLE mobili_inbox_notifications ADD COLUMN claim_id BIGINT REFERENCES claims(id);
CREATE INDEX idx_mobili_inbox_notifications_claim_id ON mobili_inbox_notifications(claim_id);
