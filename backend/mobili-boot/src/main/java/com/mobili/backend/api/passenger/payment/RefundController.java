package com.mobili.backend.api.passenger.payment;

import com.mobili.backend.module.payment.dto.RefundResult;
import com.mobili.backend.module.payment.service.PaymentRefundService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/payments")
@Slf4j
@RequiredArgsConstructor
public class RefundController {

    private final PaymentRefundService paymentRefundService;

    @PostMapping("/refund/{externalReference}")
    public ResponseEntity<RefundResult> refund(@PathVariable String externalReference) {
        log.info("💳 Requête de remboursement pour référence: {}", externalReference);
        RefundResult result = paymentRefundService.refund(externalReference);
        if (result.success()) {
            return ResponseEntity.ok(result);
        } else {
            return ResponseEntity.badRequest().body(result);
        }
    }
}
