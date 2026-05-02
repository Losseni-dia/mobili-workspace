-- Rattachement d’un utilisateur (ex. chauffeur salarié) à la compagnie employeuse, distinct du
-- one-to-one « propriétaire de fiche partenaire » (partners.user_id).
ALTER TABLE users ADD COLUMN IF NOT EXISTS employer_partner_id bigint;

-- Pas de NOT NULL : optionnel, surtout pour rôle CHAUFFEUR hors covo. solo.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_users_employer_partner'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT fk_users_employer_partner
      FOREIGN KEY (employer_partner_id) REFERENCES partners (id) ON DELETE SET NULL;
  END IF;
END $$;
