package com.mobili.backend.module.payment.service;

import com.mobili.backend.module.payment.dto.RefundResult;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@Slf4j
@RequiredArgsConstructor
public class PaymentRefundService {

    private final PaymentRepository paymentRepository;
    private final List<PaymentService> paymentServices;
    private final PaymentStatusUpdateService paymentStatusUpdateService;

    @Transactional
    public RefundResult refund(String externalReference) {
        return refund(externalReference, null);
    }

    /**
     * @param amount FCFA, null = remboursement intégral (comportement historique). Non-null =
     *               remboursement partiel — voir Booking.cancelTickets/cancelBooking pour le
     *               calcul (jamais le forfait client, quel que soit total ou partiel).
     */
    @Transactional
    public RefundResult refund(String externalReference, Long amount) {
        log.info("💳 Début de la procédure de remboursement pour référence: {} (montant={})",
                externalReference, amount == null ? "intégral" : amount);

        Payment payment = paymentRepository.findByExternalReference(externalReference)
                .orElseThrow(() -> new IllegalArgumentException("Paiement introuvable : " + externalReference));

        // REFUNDED est accepté en plus de SUCCESS : un paiement déjà partiellement remboursé
        // (annulation ciblée d'une partie des tickets d'une réservation à plusieurs sièges) doit
        // pouvoir recevoir un NOUVEAU remboursement partiel ensuite — Stripe accepte plusieurs
        // remboursements partiels sur le même paiement tant que le cumul ne dépasse pas le
        // montant payé (l'API renverra une erreur explicite sinon, jamais un remboursement en
        // double silencieux). Avant ce correctif (incident 2026-09-02), une 2e annulation sur la
        // même réservation ne trouvait plus aucun paiement remboursable : l'argent des tickets
        // annulés ensuite n'était jamais reversé au client.
        if (payment.getStatus() != PaymentStatus.SUCCESS && payment.getStatus() != PaymentStatus.REFUNDED) {
            log.error("❌ Remboursement impossible. Statut actuel: {}", payment.getStatus());
            throw new IllegalStateException("Seul un paiement au statut SUCCESS ou REFUNDED peut être remboursé.");
        }

        PaymentService paymentService = paymentServices.stream()
                .filter(s -> s.getPaymentProvider() == payment.getProvider())
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Aucun service trouvé pour le provider : " + payment.getProvider()));

        RefundResult result = amount != null
                ? paymentService.refundPayment(externalReference, amount)
                : paymentService.refundPayment(externalReference);

        if (result.success()) {
            payment.setStatus(PaymentStatus.REFUNDED);
            payment.setUpdatedAt(LocalDateTime.now());
            paymentRepository.save(payment);
            log.info("✅ Remboursement enregistré en base pour {}", externalReference);
        } else {
            log.error("❌ Échec remboursement fournisseur : {}", result.message());
        }

        return result;
    }
}
