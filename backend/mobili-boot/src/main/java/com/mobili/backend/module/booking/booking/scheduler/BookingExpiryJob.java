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
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripRunService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class BookingExpiryJob {

    private final BookingRepository bookingRepository;
    private final TripRepository tripRepository;
    private final TripRunService tripRunService;
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

            releaseSeats(b);

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

    /**
     * AUDIT-MOBILI.md §1.2 : remplace l'ancien incrément naïf
     * {@code trip.setAvailableSeats(trip.getAvailableSeats() + b.getNumberOfSeats())}, qui
     * ne reflétait pas le minimum réel par tronçon sur un trajet multi-arrêts (pouvait
     * durablement désynchroniser le compteur). Même mécanisme que
     * CovoiturageBookingExpiryScheduler.releaseSeats (déjà correct) et que
     * BookingService.create/cancelBooking/cancelTickets — jamais d'arithmétique directe sur
     * availableSeats en dehors de TripRunService.refreshTripAvailableSeatsCounter.
     */
    private void releaseSeats(Booking b) {
        Trip trip = tripRepository.findByIdWithPartnerAndStops(b.getTrip().getId()).orElse(null);
        if (trip == null) {
            return;
        }
        tripRunService.ensureStops(trip);
        tripRunService.refreshTripAvailableSeatsCounter(trip);
        tripRepository.save(trip);
    }
}
