package com.mobili.backend.api.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import com.mobili.backend.module.admin.dto.CancelBookingResponse;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;

/**
 * Couvre AdminBookingController.cancelBooking() — expose
 * BookingService.cancelBooking() (existante, testée séparément, non
 * modifiée) via un endpoint admin. Ce test vérifie uniquement le
 * comportement propre au contrôleur : détection du provider avant
 * annulation, message renvoyé à l'UI selon Stripe/FedaPay/aucun paiement.
 */
@ExtendWith(MockitoExtension.class)
class AdminBookingControllerTest {

    @Mock
    private BookingService bookingService;
    @Mock
    private PaymentRepository paymentRepository;

    private AdminBookingController controller;

    @BeforeEach
    void setUp() {
        controller = new AdminBookingController(bookingService, paymentRepository);
    }

    @Test
    void cancelBooking_stripePayment_reportsAutoRefunded() {
        Payment payment = new Payment();
        payment.setProvider(PaymentProvider.STRIPE);
        when(paymentRepository.findByBookingIdAndStatus(1L, PaymentStatus.SUCCESS))
                .thenReturn(Optional.of(payment));

        ResponseEntity<CancelBookingResponse> response = controller.cancelBooking(1L);

        verify(bookingService).cancelBooking(1L);
        CancelBookingResponse body = response.getBody();
        assertEquals(1L, body.bookingId());
        assertEquals("STRIPE", body.provider());
        assertTrue(body.autoRefunded());
        assertTrue(body.message().contains("automatiquement"));
    }

    @Test
    void cancelBooking_fedapayPayment_reportsManualRefundRequired() {
        Payment payment = new Payment();
        payment.setProvider(PaymentProvider.FEDAPAY);
        when(paymentRepository.findByBookingIdAndStatus(2L, PaymentStatus.SUCCESS))
                .thenReturn(Optional.of(payment));

        ResponseEntity<CancelBookingResponse> response = controller.cancelBooking(2L);

        verify(bookingService).cancelBooking(2L);
        CancelBookingResponse body = response.getBody();
        assertEquals("FEDAPAY", body.provider());
        assertFalse(body.autoRefunded());
        assertTrue(body.message().toLowerCase().contains("manuellement"));
    }

    @Test
    void cancelBooking_noSuccessfulPayment_reportsNoRefund() {
        when(paymentRepository.findByBookingIdAndStatus(3L, PaymentStatus.SUCCESS))
                .thenReturn(Optional.empty());

        ResponseEntity<CancelBookingResponse> response = controller.cancelBooking(3L);

        verify(bookingService).cancelBooking(3L);
        CancelBookingResponse body = response.getBody();
        assertNull(body.provider());
        assertFalse(body.autoRefunded());
    }
}
