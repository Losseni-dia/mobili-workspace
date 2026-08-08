package com.mobili.backend.module.payment.service;

import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@Slf4j
@RequiredArgsConstructor
public class PaymentStatusUpdateService {

    private final PaymentRepository paymentRepository;
    private final MeterRegistry meterRegistry;

    @Transactional
    public void markAsSuccess(String externalReference) {
        updateStatus(externalReference, PaymentStatus.SUCCESS);
    }

    @Transactional
    public void markAsSuccessWithReference(Long bookingId, String externalReference) {
        log.info("🔄 Tentative de passage à SUCCESS pour Booking #{} avec référence: {}", bookingId, externalReference);

        // 1. D'abord par externalReference : couvre le rejeu d'un webhook déjà
        //    traité (Stripe/FedaPay peuvent renvoyer le même événement plusieurs
        //    fois) — le Payment porte alors déjà cette référence depuis le premier
        //    passage, et on retombe naturellement sur la garde "déjà SUCCESS"
        //    ci-dessous.
        // 2. Sinon (premier passage, externalReference jamais écrite nulle part
        //    — c'est justement ce qu'on s'apprête à faire ci-dessous), on retrouve
        //    le paiement par bookingId + PENDING, garanti unique tous providers
        //    confondus (PaymentCreationService refuse un deuxième PENDING pour la
        //    même réservation). Sans ce repli, le tout premier passage du webhook
        //    ne trouvait jamais rien et échouait systématiquement (incident
        //    bookingId=213) — appelée aussi bien par StripeWebhookController que
        //    FedaPayCallbackController, donc pas de filtre sur le provider ici.
        Payment payment = paymentRepository
                .findByBookingIdAndExternalReference(bookingId, externalReference)
                .or(() -> paymentRepository.findByBookingIdAndStatus(bookingId, PaymentStatus.PENDING))
                .orElseThrow(() -> new IllegalArgumentException(
                        "Paiement introuvable pour le booking : " + bookingId));

        if (payment.getStatus() == PaymentStatus.SUCCESS) {
            log.warn("⚠️ Webhook doublon détecté : Le paiement pour Booking #{} est déjà au statut SUCCESS.", bookingId);
            return;
        }

        if (payment.getStatus() == PaymentStatus.FAILED || payment.getStatus() == PaymentStatus.CANCELLED) {
            log.error("❌ Transition illégale : Impossible de passer un paiement {} au statut SUCCESS pour Booking #{}", payment.getStatus(), bookingId);
            throw new IllegalStateException("Impossible de valider un paiement déjà échoué ou annulé.");
        }

        payment.setExternalReference(externalReference);
        payment.setStatus(PaymentStatus.SUCCESS);
        payment.setUpdatedAt(LocalDateTime.now());
        paymentRepository.save(payment);

        meterRegistry.counter("payment.status.update", "status", "SUCCESS", "provider", payment.getProvider().name()).increment();
        log.info("✅ Paiement passé à SUCCESS pour Booking #{}", bookingId);
    }

    @Transactional
    public void markAsFailed(String externalReference) {
        log.info("🔄 Tentative de passage à FAILED pour paiement avec référence: {}", externalReference);

        Payment payment = paymentRepository.findByExternalReference(externalReference)
                .orElseThrow(() -> new IllegalArgumentException("Paiement non trouvé : " + externalReference));

        if (payment.getStatus() == PaymentStatus.FAILED || payment.getStatus() == PaymentStatus.CANCELLED) {
            log.warn("⚠️ Paiement déjà échoué ou annulé pour référence: {}. Aucune action.", externalReference);
            return;
        }
        
        if (payment.getStatus() == PaymentStatus.SUCCESS) {
            log.error("❌ Transition illégale : Impossible de faire échouer un paiement déjà SUCCESS pour référence: {}", externalReference);
            throw new IllegalStateException("Impossible de faire échouer un paiement déjà réussi.");
        }

        payment.setStatus(PaymentStatus.FAILED);
        payment.setUpdatedAt(LocalDateTime.now());
        paymentRepository.save(payment);

        meterRegistry.counter("payment.status.update", "status", "FAILED", "provider", payment.getProvider().name()).increment();
        log.info("✅ Paiement passé à FAILED pour référence: {}", externalReference);
    }

    private void updateStatus(String externalReference, PaymentStatus status) {
        log.info("🔄 Mise à jour statut paiement {} -> {}", externalReference, status);
        
        Payment payment = paymentRepository.findByExternalReference(externalReference)
                .orElseThrow(() -> new IllegalArgumentException("Paiement non trouvé avec la référence : " + externalReference));

        payment.setStatus(status);
        payment.setUpdatedAt(LocalDateTime.now());
        paymentRepository.save(payment);
        
        meterRegistry.counter("payment.status.update", "status", status.name(), "provider", payment.getProvider().name()).increment();
        log.info("✅ Statut paiement {} mis à jour avec succès", externalReference);
    }
}
