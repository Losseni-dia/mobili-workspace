-- Fils de discussion admin ↔ partenaire/chauffeur
CREATE TABLE admin_com_threads (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    subject VARCHAR(300) NOT NULL,
    -- Participant côté admin (userId de l'admin qui a créé)
    admin_user_id BIGINT NOT NULL REFERENCES users (id),
    -- Participant côté partenaire/chauffeur
    partner_user_id BIGINT NOT NULL REFERENCES users (id),
    last_activity_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_admin_com_threads_admin ON admin_com_threads (admin_user_id);

CREATE INDEX idx_admin_com_threads_partner ON admin_com_threads (partner_user_id);

-- Messages dans le fil
CREATE TABLE admin_com_messages (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    thread_id BIGINT NOT NULL REFERENCES admin_com_threads (id) ON DELETE CASCADE,
    author_id BIGINT NOT NULL REFERENCES users (id),
    body VARCHAR(4000) NOT NULL
);

CREATE INDEX idx_admin_com_messages_thread ON admin_com_messages (thread_id);