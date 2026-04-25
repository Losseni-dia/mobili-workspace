package com.mobili.backend.module.payment.fedaPay.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verifyNoInteractions;

import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;

import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.fedaPay.service.FedaPayService;

@ExtendWith(MockitoExtension.class)
class PaymentControllerTest {

    @Mock
    private BookingService bookingService;
    @Mock
    private FedaPayService fedaPayService;

    private PaymentController paymentController;

    @BeforeEach
    void setUp() {
        paymentController = new PaymentController(bookingService, fedaPayService);
        ReflectionTestUtils.setField(paymentController, "webhookSecret", "expected-secret");
    }

    @Test
    void webhookRejectsInvalidSecretHeader() {
        ResponseEntity<Void> response = paymentController.handleWebhook(Map.of(), "wrong-secret");

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
        verifyNoInteractions(bookingService);
    }
}
