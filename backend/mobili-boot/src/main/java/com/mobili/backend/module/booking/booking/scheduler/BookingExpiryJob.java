package com.mobili.backend.module.booking.booking.scheduler;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.notification.entity.MobiliNotificationType;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.trip.entity.Trip;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class BookingExpiryJob {

    private final BookingRepository bookingRepository;
    private final InboxNotificationService inboxNotificationService;

    @Scheduled(fixedDelay = 30_000) // toutes les 30 secondes
    @Transactional
    public void expirePendingBookings() {
        LocalDateTime cutoff = LocalDateTime.now().minusMinutes(2);
        List<Booking> expired = bookingRepository
                .findByStatusAndCreatedAtBefore(BookingStatus.PENDING, cutoff);

        for (Booking b : expired) {
            b.setStatus(BookingStatus.CANCELLED);
            bookingRepository.save(b);

            // Libérer les sièges
            Trip trip = b.getTrip();
            trip.setAvailableSeats(trip.getAvailableSeats() + b.getNumberOfSeats());

            // Notifier le passager
            inboxNotificationService.notifyUser(
                    b.getCustomer(),
                    "Réservation expirée",
                    "Votre réservation " + b.getReference() +
                            " a expiré (délai de paiement dépassé). " +
                            "Veuillez recommencer votre réservation.",
                    MobiliNotificationType.BOOKING_CANCELLED);

            log.info("Réservation expirée — bookingId={} ref={}", b.getId(), b.getReference());
        }
    }
}
