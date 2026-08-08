package com.mobili.backend.module.payment.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.payment.dto.RefundResult;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;

/** Scénario "remboursement Stripe" — le SDK Stripe (StripeService) n'est pas appelé,
 * seul le PaymentService résolu pour STRIPE est mocké. */
@ExtendWith(MockitoExtension.class)
class PaymentRefundServiceTest {

    @Mock
    private PaymentRepository paymentRepository;
    @Mock
    private PaymentService stripePaymentService;
    @Mock
    private PaymentStatusUpdateService paymentStatusUpdateService;

    private PaymentRefundService paymentRefundService;

    @BeforeEach
    void setUp() {
        paymentRefundService = new PaymentRefundService(
                paymentRepository, List.of(stripePaymentService), paymentStatusUpdateService);
    }

    @Test
    void refund_marksPaymentRefundedWhenProviderSucceeds() {
        Payment payment = successPayment(PaymentProvider.STRIPE);
        when(stripePaymentService.getPaymentProvider()).thenReturn(PaymentProvider.STRIPE);
        when(paymentRepository.findByExternalReference("pi_stripe_123")).thenReturn(Optional.of(payment));
        when(stripePaymentService.refundPayment("pi_stripe_123"))
                .thenReturn(new RefundResult(true, "re_123", "Remboursement Stripe réussi"));

        RefundResult result = paymentRefundService.refund("pi_stripe_123");

        assertEquals(true, result.success());
        assertEquals(PaymentStatus.REFUNDED, payment.getStatus());
        verify(paymentRepository).save(payment);
    }

    @Test
    void refund_leavesStatusUnchangedWhenProviderFails() {
        Payment payment = successPayment(PaymentProvider.STRIPE);
        when(stripePaymentService.getPaymentProvider()).thenReturn(PaymentProvider.STRIPE);
        when(paymentRepository.findByExternalReference("pi_stripe_123")).thenReturn(Optional.of(payment));
        when(stripePaymentService.refundPayment("pi_stripe_123"))
                .thenReturn(new RefundResult(false, null, "Carte non remboursable"));

        RefundResult result = paymentRefundService.refund("pi_stripe_123");

        assertEquals(false, result.success());
        assertEquals(PaymentStatus.SUCCESS, payment.getStatus());
        verify(paymentRepository, never()).save(payment);
    }

    @Test
    void refund_rejectsPaymentNotInSuccessStatus() {
        Payment payment = successPayment(PaymentProvider.STRIPE);
        payment.setStatus(PaymentStatus.PENDING);
        when(paymentRepository.findByExternalReference("pi_stripe_123")).thenReturn(Optional.of(payment));

        assertThrows(IllegalStateException.class, () -> paymentRefundService.refund("pi_stripe_123"));
    }

    private Payment successPayment(PaymentProvider provider) {
        Payment payment = new Payment();
        payment.setId(20L);
        payment.setBookingId(1L);
        payment.setProvider(provider);
        payment.setStatus(PaymentStatus.SUCCESS);
        payment.setExternalReference("pi_stripe_123");
        return payment;
    }
}
