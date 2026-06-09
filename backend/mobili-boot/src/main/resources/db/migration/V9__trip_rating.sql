-- V9__trip_rating.sql
CREATE TABLE trip_ratings (
    id BIGSERIAL PRIMARY KEY,
    trip_id BIGINT NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    note SMALLINT NOT NULL CHECK (note BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (trip_id, user_id) -- un seul avis par utilisateur par voyage
);

CREATE INDEX idx_trip_ratings_trip_id ON trip_ratings (trip_id);

CREATE INDEX idx_trip_ratings_user_id ON trip_ratings (user_id);