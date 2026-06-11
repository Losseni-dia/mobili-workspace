ALTER TABLE mobili_inbox_notifications
DROP CONSTRAINT IF EXISTS mobili_inbox_notifications_type_check;

ALTER TABLE mobili_inbox_notifications
ADD CONSTRAINT mobili_inbox_notifications_type_check CHECK (
    type IN (
        'TICKET_ISSUED',
        'TRIP_CHANNEL_MESSAGE',
        'PARTNER_NEW_BOOKING',
        'GARE_STATION_NEW_BOOKING',
        'PARTNER_GARE_COM_MESSAGE',
        'COV_KYC_EXPIRING_SOON',
        'COV_KYC_EXPIRED',
        'MOBILI_ADMIN_INFO_PARTNER',
        'BOOKING_CANCELLED'
    )
);