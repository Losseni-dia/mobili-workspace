-- HOTFIX incident prod : V45 a déclaré ces 4 colonnes en NUMERIC alors que les champs Java
-- correspondants sont des Double/double (Booking.ticketsTotalAmount, Ticket.transportFare/
-- baggageFee/commissionRate) — exactement comme TOUS les autres champs monétaires déjà
-- existants dans le projet (bookings.total_price, tickets.amount_paid, trips.price... tous en
-- "double precision", voir V2__schema_baseline_idempotent.sql). Hibernate (ddl-auto: validate)
-- attend "float(53)" (= double precision) pour un champ Double, pas NUMERIC — d'où le crash au
-- démarrage ("wrong column type ... found [numeric], but expecting [float(53)]").
--
-- Correctif : aligner le type SQL sur le type Java déjà utilisé partout ailleurs pour l'argent
-- dans ce projet (Double), PAS l'inverse — passer ces champs en BigDecimal introduirait un
-- mélange de types incohérent au sein des mêmes entités Booking/Ticket (certains champs
-- Double, d'autres BigDecimal) et casserait à nouveau le même genre de correspondance.
--
-- Ces colonnes n'ont jamais pu être écrites en prod (l'appli n'a jamais réussi à démarrer
-- depuis leur création par V45), USING n'est donc là que par prudence, pas pour préserver des
-- données réelles.
ALTER TABLE bookings ALTER COLUMN tickets_total_amount TYPE double precision USING tickets_total_amount::double precision;
ALTER TABLE tickets ALTER COLUMN transport_fare TYPE double precision USING transport_fare::double precision;
ALTER TABLE tickets ALTER COLUMN baggage_fee TYPE double precision USING baggage_fee::double precision;
ALTER TABLE tickets ALTER COLUMN commission_rate TYPE double precision USING commission_rate::double precision;
