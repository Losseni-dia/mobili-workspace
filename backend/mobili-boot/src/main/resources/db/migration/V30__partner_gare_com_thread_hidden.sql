CREATE TABLE partner_gare_com_thread_hidden (
    id BIGSERIAL PRIMARY KEY,
    thread_id BIGINT NOT NULL REFERENCES partner_gare_com_threads (id) ON DELETE CASCADE,
    user_id BIGINT REFERENCES users (id),
    station_id BIGINT REFERENCES stations (id),
    hidden_at TIMESTAMP NOT NULL,
    UNIQUE (thread_id, user_id),
    UNIQUE (thread_id, station_id)
);