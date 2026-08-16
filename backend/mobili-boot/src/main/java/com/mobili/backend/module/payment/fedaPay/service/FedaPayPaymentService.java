package com.mobili.backend.module.payment.fedaPay.service;

import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.payment.dto.RefundResult;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.service.PaymentService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
public class FedaPayPaymentService implements PaymentService {

    private final FedaPayService fedaPayService;
    // Injection du repository (et non de BookingService) pour éviter un cycle
    // de beans : BookingService dépend déjà de PaymentRefundService, qui
    // dépend de List<PaymentService> — donc de FedaPayPaymentService lui-même.
    private final BookingRepository bookingRepository;

    @Override
    @Transactional
    public String createPaymentSession(Long bookingId, Long amount, String currency, String customerEmail,
            String frontendBaseUrl) {
        log.info("🚀 Délégation création session FedaPay pour Booking #{}", bookingId);

        // FedaPayService attend un double pour amount
        FedaPayService.FedaPayCheckoutResult result = fedaPayService.createPaymentSession(
                amount.doubleValue(),
                customerEmail != null ? customerEmail : "client@mobili.com",
                bookingId,
                frontendBaseUrl
        );

        // Persistance de l'ID transaction FedaPay, indispensable à la vérification
        // ultérieure (POST /payments/verify/{bookingId}) — contrat PaymentService
        // inchangé : cet ID ne remonte pas au-delà de ce service.
        recordTransactionId(bookingId, result.transactionId());

        return result.paymentUrl();
    }

    private void recordTransactionId(Long bookingId, String transactionId) {
        if (transactionId == null || transactionId.isBlank()) {
            return;
        }
        bookingRepository.findById(bookingId).ifPresent(booking -> {
            if (booking.getStatus() != BookingStatus.PENDING
                    && booking.getStatus() != BookingStatus.AWAITING_PAYMENT) {
                return;
            }
            booking.setFedapayTransactionId(transactionId);
            bookingRepository.save(booking);
        });
    }

    @Override
    public RefundResult refundPayment(String externalReference) {
        log.info("💳 Appel remboursement FedaPay pour référence: {}", externalReference);
        try {
            String refundId = fedaPayService.refund(externalReference);
            return new RefundResult(true, refundId, "Remboursement FedaPay réussi");
        } catch (UnsupportedOperationException e) {
            // Limitation connue de FedaPay (pas un bug MOBILI) : voir FedaPayService.refund().
            log.warn("⚠️ Remboursement FedaPay demandé pour {} : non supporté par l'API FedaPay, "
                    + "à traiter manuellement depuis leur dashboard.", externalReference);
            return new RefundResult(false, null,
                    "Remboursement FedaPay indisponible automatiquement : FedaPay ne permet les "
                            + "remboursements (MTN Mobile Money uniquement) que manuellement, depuis le "
                            + "dashboard marchand FedaPay. Merci de le traiter directement sur "
                            + "dashboard.fedapay.com.");
        } catch (Exception e) {
            log.error("💥 Erreur remboursement FedaPay pour {} : {}", externalReference, e.getMessage(), e);
            return new RefundResult(false, null,
                    "Erreur technique lors du remboursement FedaPay. Merci de contacter le support.");
        }
    }

    @Override
    public PaymentProvider getPaymentProvider() {
        return PaymentProvider.FEDAPAY;
    }
}
