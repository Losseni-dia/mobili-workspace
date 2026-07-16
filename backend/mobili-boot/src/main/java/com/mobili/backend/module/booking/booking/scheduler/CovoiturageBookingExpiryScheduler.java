package com.mobili.backend.module.booking.booking.scheduler;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripRunService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Fait expirer automatiquement les demandes covoiturage :
 * - Chauffeur n'a pas répondu sous 24h → EXPIRED, passager notifié.
 * - Chauffeur a accepté mais passager n'a pas payé sous 30 min → EXPIRED,
 * place libérée, passager notifié.
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class CovoiturageBookingExpiryScheduler {

    private final BookingRepository bookingRepository;
    private final TripRepository tripRepository;
    private final TripRunService tripRunService;
    private final InboxNotificationService inboxNotificationService;

    @Scheduled(fixedRate = 5 * 60 * 1000) // toutes les 5 minutes
    @Transactional
    public void expireStaleCovoiturageRequests() {
        LocalDateTime now = LocalDateTime.now();

        List<Booking> noResponse = bookingRepository.findByStatusAndDriverResponseDeadlineBefore(
                BookingStatus.PENDING_DRIVER_APPROVAL, now);
        for (Booking b : noResponse) {
            b.setStatus(BookingStatus.EXPIRED);
            bookingRepository.save(b);
            releaseSeats(b);
            inboxNotificationService.notifyPassengerOnCovoiturageNoResponse(b);
            log.info("Demande covoiturage #{} expirée (pas de réponse chauffeur)", b.getId());
        }

        List<Booking> paymentExpired = bookingRepository.findByStatusAndPaymentDeadlineBefore(
                BookingStatus.AWAITING_PAYMENT, now);
        for (Booking b : paymentExpired) {
            b.setStatus(BookingStatus.EXPIRED);
            bookingRepository.save(b);
            releaseSeats(b);
            inboxNotificationService.notifyPassengerOnCovoiturageBookingPaymentExpired(b);
            log.info("Demande covoiturage #{} expirée (délai de paiement dépassé)", b.getId());
        }
    }

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