-- Coordonnees GPS optionnelles par arret (nullable) — necessaires pour resoudre la destination
-- de l'appel Directions (module routing). Renseignees manuellement pour l'instant (pas
-- d'interface de saisie dans ce chantier) ; un arret sans coordonnees rend le calcul d'ETA
-- indisponible pour ce trajet, jamais une estimation approximative.
ALTER TABLE trip_stops ADD COLUMN latitude DOUBLE PRECISION;
ALTER TABLE trip_stops ADD COLUMN longitude DOUBLE PRECISION;
