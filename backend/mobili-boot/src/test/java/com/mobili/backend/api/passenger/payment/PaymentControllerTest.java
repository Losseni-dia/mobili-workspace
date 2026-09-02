package com.mobili.backend.api.passenger.payment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.dto.ExchangeResult;
import com.mobili.backend.module.payment.dto.PaymentRequest;
import com.mobili.backend.module.payment.dto.PaymentResponse;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.fedaPay.dto.PaymentVerifyResponse;
import com.mobili.backend.module.payment.fedaPay.service.FedaPayService;
import com.mobili.backend.module.payment.service.ExchangeRateService;
import com.mobili.backend.module.payment.service.FrontendReturnUrlResolver;
import com.mobili.backend.module.payment.service.PaymentCreationService;
import com.mobili.backend.module.payment.service.PaymentGatewayResolver;
import com.mobili.backend.module.payment.service.PaymentService;
import com.mobili.backend.module.payment.service.PaymentStatusUpdateService;

/**
 * Note : la logique de webhook FedaPay a été déplacée vers {@link FedaPayCallbackController}
 * (voir son propre test dédié). Ce test couvre les 2 endpoints actuels de PaymentController :
 * la création de session de paiement (createCheckout) et la vérification côté client
 * (verifyAndConfirm).
 */
@ExtendWith(MockitoExtension.class)
class PaymentControllerTest {

    @Mock
    private BookingService bookingService;
    @Mock
    private FedaPayService fedaPayService;
    @Mock
    private PaymentGatewayResolver paymentGatewayResolver;
    @Mock
    private PaymentCreationService paymentCreationService;
    @Mock
    private ExchangeRateService exchangeRateService;
    @Mock
    private PaymentService paymentService;
    @Mock
    private FrontendReturnUrlResolver frontendReturnUrlResolver;
    @Mock
    private PaymentStatusUpdateService paymentStatusUpdateService;

    private PaymentController paymentController;

    @BeforeEach
    void setUp() {
        paymentController = new PaymentController(
                bookingService,
                fedaPayService,
                paymentGatewayResolver,
                paymentCreationService,
                exchangeRateService,
                frontendReturnUrlResolver,
                paymentStatusUpdateService);
    }

    @Test
    void createCheckoutBuildsPaymentSessionForRequestedProvider() {
        Booking booking = new Booking();
        booking.setId(1L);
        booking.setTotalPrice(10_000d);
        when(bookingService.findById(1L)).thenReturn(booking);

        ExchangeResult exchangeResult = new ExchangeResult(
                BigDecimal.valueOf(15), BigDecimal.valueOf(0.0015), "XOF", "EUR");
        when(exchangeRateService.convert(10_000L, "XOF", "EUR")).thenReturn(exchangeResult);

        Payment payment = new Payment();
        payment.setId(42L);
        payment.setProvider(PaymentProvider.STRIPE);
        payment.setStatus(PaymentStatus.PENDING);
        when(paymentCreationService.createPayment(
                eq(1L), eq(PaymentProvider.STRIPE), eq(15L), eq("EUR"),
                eq(10_000L), eq("XOF"), eq(exchangeResult.exchangeRate())))
                .thenReturn(payment);

        when(paymentGatewayResolver.resolve(PaymentProvider.STRIPE)).thenReturn(paymentService);
        when(frontendReturnUrlResolver.resolve(any())).thenReturn("https://staging.my-mobili.com");
        when(paymentService.createPaymentSession(
                1L, 15L, "EUR", "client@mobili.test", "https://staging.my-mobili.com"))
                .thenReturn("https://stripe.example/checkout/session");

        PaymentRequest request = new PaymentRequest(PaymentProvider.STRIPE, "client@mobili.test");
        ResponseEntity<PaymentResponse> response =
                paymentController.createCheckout(1L, request, new MockHttpServletRequest());

        assertEquals(200, response.getStatusCode().value());
        PaymentResponse body = response.getBody();
        assertEquals(42L, body.paymentId());
        assertEquals(1L, body.bookingId());
        assertEquals(PaymentProvider.STRIPE, body.provider());
        assertEquals(PaymentStatus.PENDING, body.status());
        assertEquals("https://stripe.example/checkout/session", body.paymentUrl());
        assertEquals(15L, body.amount());
        assertEquals("EUR", body.currency());
    }

    @Test
    void verifyAndConfirmReturnsAlreadyConfirmedWithoutCallingFedaPay() {
        Booking booking = new Booking();
        booking.setId(2L);
        booking.setStatus(BookingStatus.CONFIRMED);
        when(bookingService.findById(2L)).thenReturn(booking);

        ResponseEntity<PaymentVerifyResponse> response = paymentController.verifyAndConfirm(2L);

        assertTrue(response.getBody().confirmed());
        assertEquals(BookingStatus.CONFIRMED.name(), response.getBody().status());
        verify(fedaPayService, never()).isTransactionApprovedForBooking(any());
    }

    @Test
    void verifyAndConfirmConfirmsBookingWhenFedaPayTransactionApproved() {
        Booking booking = new Booking();
        booking.setId(3L);
        booking.setStatus(BookingStatus.AWAITING_PAYMENT);
        booking.setFedapayTransactionId("fedapay-tx-123");
        when(bookingService.findById(3L)).thenReturn(booking);
        when(fedaPayService.isTransactionApprovedForBooking("fedapay-tx-123")).thenReturn(true);

        ResponseEntity<PaymentVerifyResponse> response = paymentController.verifyAndConfirm(3L);

        assertTrue(response.getBody().confirmed());
        assertEquals(BookingStatus.CONFIRMED.name(), response.getBody().status());
        // Incident 2026-09-02 : sans cet appel, le Payment restait bloqué PENDING pour toute
        // résa confirmée via ce chemin (vérification active FedaPay, primaire en prod) — une
        // annulation admin ultérieure affichait alors à tort "aucun paiement lié à cette
        // réservation" malgré un paiement Mobile Money bien reçu.
        verify(paymentStatusUpdateService).markAsSuccessWithReference(3L, "fedapay-tx-123");
        verify(bookingService).confirmBookingAfterPayment(3L);
    }

    @Test
    void verifyAndConfirmReturnsNotConfirmedWhenNoTransactionIdRecorded() {
        Booking booking = new Booking();
        booking.setId(4L);
        booking.setStatus(BookingStatus.PENDING);
        when(bookingService.findById(4L)).thenReturn(booking);

        ResponseEntity<PaymentVerifyResponse> response = paymentController.verifyAndConfirm(4L);

        assertEquals(false, response.getBody().confirmed());
        verify(fedaPayService, never()).isTransactionApprovedForBooking(any());
        verify(bookingService, never()).confirmBookingAfterPayment(anyLong());
    }
}
