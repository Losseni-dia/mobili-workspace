package com.mobili.backend.module.payment.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;

/**
 * Couvre la logique métier commune appelée par StripeWebhookController et
 * FedaPayCallbackController après vérification de signature/secret :
 * PaymentStatusUpdateService.markAsSuccessWithReference() puis
 * PaymentConfirmationService.confirmPayment(). Les deux contrôleurs HTTP
 * délèguent exactement à cette même paire de méthodes — les scénarios
 * "Stripe réussi" et "FedaPay réussi" exercent donc le même code métier
 * provider-agnostique. La vérification de signature Stripe elle-même
 * (com.stripe.net.Webhook, méthode statique du SDK) n'est pas couverte ici —
 * limite connue, documentée dans l'audit plutôt qu'ignorée silencieusement.
 */
@ExtendWith(MockitoExtension.class)
class PaymentWebhookFlowTest {

    @Mock
    private PaymentRepository paymentRepository;
    @Mock
    private BookingRepository bookingRepository;
    @Mock
    private BookingService bookingService;

    private PaymentStatusUpdateService paymentStatusUpdateService;
    private PaymentConfirmationService paymentConfirmationService;

    @BeforeEach
    void setUp() {
        var meterRegistry = new SimpleMeterRegistry();
        paymentStatusUpdateService = new PaymentStatusUpdateService(paymentRepository, meterRegistry);
        paymentConfirmationService = new PaymentConfirmationService(
                paymentRepository, bookingService, bookingRepository, meterRegistry);
    }

    @Test
    void stripePaymentSuccess_marksPaymentSuccessAndConfirmsBooking() {
        Payment payment = pendingPayment(PaymentProvider.STRIPE);
        Booking booking = pendingBooking();
        when(paymentRepository.findByBookingIdAndExternalReference(1L, "pi_stripe_123"))
                .thenReturn(Optional.of(payment));
        when(paymentRepository.findByExternalReference("pi_stripe_123")).thenReturn(Optional.of(payment));
        when(bookingRepository.findById(1L)).thenReturn(Optional.of(booking));

        paymentStatusUpdateService.markAsSuccessWithReference(1L, "pi_stripe_123");
        paymentConfirmationService.confirmPayment("pi_stripe_123");

        assertEquals(PaymentStatus.SUCCESS, payment.getStatus());
        verify(bookingService).confirmBookingAfterPayment(1L);
    }

    @Test
    void fedaPayPaymentSuccess_marksPaymentSuccessAndConfirmsBooking() {
        Payment payment = pendingPayment(PaymentProvider.FEDAPAY);
        Booking booking = pendingBooking();
        when(paymentRepository.findByBookingIdAndExternalReference(1L, "fedapay_tx_456"))
                .thenReturn(Optional.of(payment));
        when(paymentRepository.findByExternalReference("fedapay_tx_456")).thenReturn(Optional.of(payment));
        when(bookingRepository.findById(1L)).thenReturn(Optional.of(booking));

        paymentStatusUpdateService.markAsSuccessWithReference(1L, "fedapay_tx_456");
        paymentConfirmationService.confirmPayment("fedapay_tx_456");

        assertEquals(PaymentStatus.SUCCESS, payment.getStatus());
        verify(bookingService).confirmBookingAfterPayment(1L);
    }

    @Test
    void webhookReplayedTwice_isIdempotent() {
        Payment payment = pendingPayment(PaymentProvider.STRIPE);
        Booking booking = pendingBooking();
        when(paymentRepository.findByBookingIdAndExternalReference(1L, "pi_stripe_123"))
                .thenReturn(Optional.of(payment));
        when(paymentRepository.findByExternalReference("pi_stripe_123")).thenReturn(Optional.of(payment));
        when(bookingRepository.findById(1L)).thenReturn(Optional.of(booking));

        // 1er passage du webhook (nominal).
        paymentStatusUpdateService.markAsSuccessWithReference(1L, "pi_stripe_123");
        paymentConfirmationService.confirmPayment("pi_stripe_123");
        // bookingService est mocké : on simule ce que confirmBookingAfterPayment()
        // ferait réellement (passer le booking à CONFIRMED) pour pouvoir vérifier
        // la garde anti-double-confirmation au 2e passage.
        booking.setStatus(BookingStatus.CONFIRMED);

        // 2e passage du même webhook (rejeu Stripe/FedaPay, ex. après un timeout
        // côté fournisseur qui n'a pas vu la réponse 200 à temps).
        paymentStatusUpdateService.markAsSuccessWithReference(1L, "pi_stripe_123");
        paymentConfirmationService.confirmPayment("pi_stripe_123");

        // Statut inchangé, booking confirmé une seule fois, aucune exception levée.
        assertEquals(PaymentStatus.SUCCESS, payment.getStatus());
        verify(bookingService, times(1)).confirmBookingAfterPayment(1L);
    }

    @Test
    void markAsSuccessWithReference_rejectsTransitionFromFailed() {
        Payment payment = pendingPayment(PaymentProvider.STRIPE);
        payment.setStatus(PaymentStatus.FAILED);
        when(paymentRepository.findByBookingIdAndExternalReference(1L, "pi_stripe_123"))
                .thenReturn(Optional.of(payment));

        assertThrows(IllegalStateException.class,
                () -> paymentStatusUpdateService.markAsSuccessWithReference(1L, "pi_stripe_123"));
    }

    private Payment pendingPayment(PaymentProvider provider) {
        Payment payment = new Payment();
        payment.setId(10L);
        payment.setBookingId(1L);
        payment.setProvider(provider);
        payment.setStatus(PaymentStatus.PENDING);
        payment.setOriginalAmount(10_000L);
        payment.setOriginalCurrency("XOF");
        return payment;
    }

    private Booking pendingBooking() {
        Booking booking = new Booking();
        booking.setId(1L);
        booking.setTotalPrice(10_000d);
        booking.setStatus(BookingStatus.PENDING);
        return booking;
    }
}
