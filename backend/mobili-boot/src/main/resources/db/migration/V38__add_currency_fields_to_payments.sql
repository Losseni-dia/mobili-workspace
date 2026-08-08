-- Migration pour ajouter les colonnes de conversion de devise à la table payments
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS original_amount BIGINT,
ADD COLUMN IF NOT EXISTS original_currency VARCHAR(10),
ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(19, 4);

-- Commentaires pour la documentation de la base
COMMENT ON COLUMN payments.original_amount IS 'Montant métier initial (en centimes, devise d origine)';
COMMENT ON COLUMN payments.original_currency IS 'Devise métier (ex: XOF)';
COMMENT ON COLUMN payments.exchange_rate IS 'Taux de change appliqué lors de la transaction';
