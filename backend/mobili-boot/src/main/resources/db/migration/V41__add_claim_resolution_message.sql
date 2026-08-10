-- Message de clôture rédigé par l'admin, distinct de admin_note (interne, jamais
-- renvoyé au passager) : celui-ci est visible par l'utilisateur, envoyé aussi dans la
-- notification de clôture (voir InboxNotificationService.notifyUser).
ALTER TABLE claims ADD COLUMN resolution_message VARCHAR(2000);
