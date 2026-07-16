-- Retrait du workflow de validation des gares : desormais la societe cree
-- ses gares directement, operationnelles immediatement (plus d'etape
-- d'approbation par le dirigeant).
UPDATE stations SET active = true WHERE active = false;
ALTER TABLE stations DROP COLUMN IF EXISTS approval_status;
ALTER TABLE stations DROP COLUMN IF EXISTS validated;
