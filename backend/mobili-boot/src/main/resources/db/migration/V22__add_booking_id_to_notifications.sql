ALTER TABLE mobili_inbox_notifications ADD COLUMN booking_id BIGINT;

ALTER TABLE mobili_inbox_notifications
ADD CONSTRAINT fk_notification_booking FOREIGN KEY (booking_id) REFERENCES bookings (id);