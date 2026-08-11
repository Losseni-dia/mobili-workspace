-- Forfait client (Booking) : montant total de tickets ayant servi de base au calcul du
-- forfait (traçabilité, interrogeable indépendamment du barème actuel) + forfait figé.
ALTER TABLE bookings ADD COLUMN tickets_total_amount NUMERIC;
ALTER TABLE bookings ADD COLUMN service_fee INTEGER;

-- Commission compagnie (Ticket) : décomposition transport/bagage distincte (jamais fusionnée,
-- nécessaire pour recalculer/auditer la commission sans ambiguïté) + taux et montant figés au
-- moment de la vente + position dans le compteur mensuel qui a déterminé ce taux.
ALTER TABLE tickets ADD COLUMN transport_fare NUMERIC;
ALTER TABLE tickets ADD COLUMN baggage_fee NUMERIC;
ALTER TABLE tickets ADD COLUMN commission_rate NUMERIC(4,2);
ALTER TABLE tickets ADD COLUMN commission_amount INTEGER;
ALTER TABLE tickets ADD COLUMN monthly_sequence_number INTEGER;

-- Compteur mensuel de tickets vendus par compagnie — jamais recréé en cours de mois, jamais
-- décrémenté (barème progressif non rétroactif, décision ferme). Concurrence gérée par verrou
-- pessimiste applicatif (JPA @Lock PESSIMISTIC_WRITE), pas par contrainte SQL.
CREATE TABLE partner_monthly_ticket_counters (
    id BIGSERIAL PRIMARY KEY,
    partner_id BIGINT NOT NULL REFERENCES partners(id),
    year_month VARCHAR(7) NOT NULL,
    ticket_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (partner_id, year_month)
);
