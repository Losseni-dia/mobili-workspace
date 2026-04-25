-- Colonne d’identification du partenaire « pool » covoiturage.
-- Sur base existante : ALTER + MAJ. Sur toute première install, la table peut ne pas exister : tout est ignoré
-- (Hibernate crée alors la table avec l’entité, incluant covoiturage_solo_pool).
DO $m$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = current_schema()
      AND table_name = 'partners'
  ) THEN
    ALTER TABLE partners
      ADD COLUMN IF NOT EXISTS covoiturage_solo_pool boolean NOT NULL DEFAULT false;

    UPDATE partners
    SET covoiturage_solo_pool = true
    WHERE UPPER(TRIM(registration_code)) = 'MOBICOVITU01'
      AND covoiturage_solo_pool = false;
  END IF;
END
$m$;
