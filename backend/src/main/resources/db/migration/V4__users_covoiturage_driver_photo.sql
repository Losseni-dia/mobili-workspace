-- Portrait conducteur (inscription covoiturage) — vérification KYC.
ALTER TABLE users ADD COLUMN IF NOT EXISTS covoiturage_driver_photo_url varchar(255);
