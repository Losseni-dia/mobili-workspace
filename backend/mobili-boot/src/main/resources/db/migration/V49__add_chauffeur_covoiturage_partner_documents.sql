-- Chauffeur société (nouveau : aucun document collecté jusqu'ici)
ALTER TABLE users
    ADD COLUMN chauffeur_id_front_url VARCHAR(500),
    ADD COLUMN chauffeur_id_back_url VARCHAR(500),
    ADD COLUMN chauffeur_license_front_url VARCHAR(500),
    ADD COLUMN chauffeur_license_back_url VARCHAR(500);

-- Covoiturage : permis + photo carte grise (le numéro covoiturage_grey_card_number existe déjà)
ALTER TABLE users
    ADD COLUMN covoiturage_license_front_url VARCHAR(500),
    ADD COLUMN covoiturage_license_back_url VARCHAR(500),
    ADD COLUMN covoiturage_grey_card_front_url VARCHAR(500),
    ADD COLUMN covoiturage_grey_card_back_url VARCHAR(500);

-- Société : carte de transporteur (licence pro), en plus de la CNI dirigeant déjà existante
ALTER TABLE partners
    ADD COLUMN transport_card_front_url VARCHAR(500),
    ADD COLUMN transport_card_back_url VARCHAR(500);
