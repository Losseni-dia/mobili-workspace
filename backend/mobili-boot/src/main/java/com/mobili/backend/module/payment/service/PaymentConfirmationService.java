package com.mobili.backend.module.payment.service;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
public class PaymentConfirmationService {

    private final PaymentRepository paymentRepository;
    private final BookingService bookingService;
    private final BookingRepository bookingRepository;
    private final MeterRegistry meterRegistry;

    @Transactional
    public void confirmPayment(String externalReference) {
        log.info("🔔 Début de la confirmation métier pour le paiement avec référence: {}", externalReference);

        // 1. Retrouver le paiement
        Payment payment = paymentRepository.findByExternalReference(externalReference)
                .orElseThrow(() -> new IllegalArgumentException("Paiement non trouvé : " + externalReference));

        // 2. Vérifier l'état actuel (doit être SUCCESS)
        if (payment.getStatus() != PaymentStatus.SUCCESS) {
            log.error("❌ Tentative de confirmation d'un paiement non réussi. Statut actuel: {}", payment.getStatus());
            throw new IllegalStateException("Le paiement n'est pas au statut SUCCESS : " + payment.getStatus());
        }

        // 3. Retrouver et vérifier le Booking
        Booking booking = bookingRepository.findById(payment.getBookingId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));

        // 4. Protection contre double confirmation métier
        if (booking.getStatus() == BookingStatus.CONFIRMED) {
            log.warn("⚠️ La réservation {} est déjà confirmée. Aucune action nécessaire.", booking.getId());
            meterRegistry.counter("payment.confirmation", "result", "ALREADY_CONFIRMED").increment();
            return;
        }

        // 5. Vérification de cohérence financière
        long bookingPrice = Math.round(booking.getTotalPrice());
        if (Math.abs(payment.getOriginalAmount() - bookingPrice) > 1) { // Tolérance de 1 unité (arrondis)
            log.error("❌ Incohérence financière pour Booking #{}. Attendu: {}, Payé: {}",
                    booking.getId(), bookingPrice, payment.getOriginalAmount());
            meterRegistry.counter("payment.confirmation", "result", "INCONSISTENCY_FAILURE").increment();
            throw new IllegalStateException("Incohérence financière détectée lors de la confirmation.");
        }

        // 6. Appeler BookingService pour confirmer la réservation
        log.info("✅ Paiement validé. Confirmation métier du Booking #{}", booking.getId());
        bookingService.confirmBookingAfterPayment(booking.getId());

        meterRegistry.counter("payment.confirmation", "result", "SUCCESS").increment();
        log.info("🚀 Confirmation métier du Booking #{} terminée avec succès", booking.getId());
    }
}
