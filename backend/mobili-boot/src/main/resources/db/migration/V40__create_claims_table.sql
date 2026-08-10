-- Système de réclamation générique (motif + réservation liée optionnelle + champs libres)
CREATE TABLE IF NOT EXISTS claims (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    reason VARCHAR(40) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'RECEIVED',
    booking_id BIGINT REFERENCES bookings(id),
    message VARCHAR(2000) NOT NULL,
    details_json VARCHAR(2000),
    admin_note VARCHAR(2000),
    handled_by_admin_id BIGINT REFERENCES users(id),
    resolved_at TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_claims_user_id ON claims(user_id);
CREATE INDEX idx_claims_status ON claims(status);
CREATE INDEX idx_claims_booking_id ON claims(booking_id);
