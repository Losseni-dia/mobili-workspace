ALTER TABLE bookings DROP CONSTRAINT bookings_status_check;

ALTER TABLE bookings
ADD CONSTRAINT bookings_status_check CHECK (
    status IN (
        'PENDING',
        'CONFIRMED',
        'CANCELLED',
        'COMPLETED',
        'OFFLINE_SALE',
        'PENDING_DRIVER_APPROVAL',
        'AWAITING_PAYMENT',
        'REJECTED_BY_DRIVER',
        'EXPIRED'
    )
);