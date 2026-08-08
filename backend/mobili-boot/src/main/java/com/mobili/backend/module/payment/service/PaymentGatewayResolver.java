package com.mobili.backend.module.payment.service;

import com.mobili.backend.module.payment.enums.PaymentProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@Slf4j
@RequiredArgsConstructor
public class PaymentGatewayResolver {

    private final List<PaymentService> paymentServices;

    /**
     * Recherche l'implémentation de PaymentService correspondant au provider donné.
     */
    public PaymentService resolve(PaymentProvider provider) {
        return paymentServices.stream()
                .filter(service -> service.getPaymentProvider() == provider)
                .findFirst()
                .orElseThrow(() -> {
                    log.error("❌ Aucun PaymentService trouvé pour le provider : {}", provider);
                    return new IllegalArgumentException("Provider non supporté : " + provider);
                });
    }
}
