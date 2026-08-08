package com.mobili.backend.module.payment.fedaPay.service;

import com.mobili.backend.module.payment.dto.RefundResult;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.service.PaymentService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class FedaPayPaymentService implements PaymentService {

    private final FedaPayService fedaPayService;

    @Override
    public String createPaymentSession(Long bookingId, Long amount, String currency, String customerEmail) {
        log.info("🚀 Délégation création session FedaPay pour Booking #{}", bookingId);

        // FedaPayService attend un double pour amount
        FedaPayService.FedaPayCheckoutResult result = fedaPayService.createPaymentSession(
                amount.doubleValue(),
                customerEmail != null ? customerEmail : "client@mobili.com",
                bookingId
        );

        return result.paymentUrl();
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
