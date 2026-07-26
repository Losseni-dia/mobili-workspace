ALTER TABLE mobili_inbox_notifications 
DROP CONSTRAINT mobili_inbox_notifications_type_check;

ALTER TABLE mobili_inbox_notifications 
ADD CONSTRAINT mobili_inbox_notifications_type_check 
CHECK (((type)::text = ANY ((ARRAY[
    'TICKET_ISSUED'::character varying,
    'TRIP_CHANNEL_MESSAGE'::character varying,
    'PARTNER_NEW_BOOKING'::character varying,
    'GARE_STATION_NEW_BOOKING'::character varying,
    'PARTNER_GARE_COM_MESSAGE'::character varying,
    'COV_KYC_EXPIRING_SOON'::character varying,
    'COV_KYC_EXPIRED'::character varying,
    'MOBILI_ADMIN_INFO_PARTNER'::character varying,
    'PARTNER_SUBMISSION_PENDING'::character varying,
    'BOOKING_CANCELLED'::character varying,
    'PARTNER_APPROVED'::character varying,
    'PARTNER_REJECTED'::character varying,
    'COV_KYC_APPROVED'::character varying,
    'COV_KYC_REJECTED'::character varying,
    'COVOITURAGE_BOOKING_REQUEST'::character varying,
    'COVOITURAGE_BOOKING_ACCEPTED'::character varying,
    'COVOITURAGE_BOOKING_REJECTED'::character varying,
    'COVOITURAGE_BOOKING_NO_RESPONSE'::character varying,
    'COVOITURAGE_BOOKING_PAYMENT_EXPIRED'::character varying
])::text[])));
