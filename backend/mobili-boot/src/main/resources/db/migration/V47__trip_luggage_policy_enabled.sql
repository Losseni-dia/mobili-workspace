-- Distingue les trajets dont le partenaire a explicitement configuré la politique bagages
-- (formulaire "Bagages (passagers)", add-trip/trip-edit) de ceux qui n'ont jamais été
-- configurés (politique par défaut 1 cabine + 1 soute silencieusement appliquée). Sans ce
-- champ, impossible côté réservation de savoir si la section "Bagages" doit s'afficher —
-- tous les trajets historiques passent à false (comportement inchangé pour l'existant).
ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS luggage_policy_enabled BOOLEAN NOT NULL DEFAULT false;
