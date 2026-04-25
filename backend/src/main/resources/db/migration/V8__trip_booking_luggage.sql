-- Politique bagages (type FlixBus : cabine + soute inclus, option payante en soute)
ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS included_cabin_bags_per_passenger INT NOT NULL DEFAULT 1;
ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS included_hold_bags_per_passenger INT NOT NULL DEFAULT 1;
ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS max_extra_hold_bags_per_passenger INT NOT NULL DEFAULT 1;
ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS extra_hold_bag_price DOUBLE PRECISION NOT NULL DEFAULT 0;

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS extra_hold_bags INT NOT NULL DEFAULT 0;
