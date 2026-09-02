-- Suivi cumulatif des bagages soute supplémentaires déjà remboursés sur une réservation —
-- une annulation (ticket ou réservation entière) peut se faire en plusieurs fois, jamais
-- automatique : l'admin déclare explicitement combien de bagages annuler à chaque fois (voir
-- BookingService.cancelTickets/cancelBooking). Ce compteur empêche de déclarer/rembourser plus
-- de bagages qu'il n'y en a réellement d'enregistrés sur la réservation (extra_hold_bags), même
-- cumulé sur plusieurs annulations successives.
ALTER TABLE bookings ADD COLUMN refunded_extra_hold_bags INTEGER NOT NULL DEFAULT 0;
