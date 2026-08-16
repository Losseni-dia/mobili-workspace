package com.mobili.backend.api.passenger.payment;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.dto.PaymentRequest;
import com.mobili.backend.module.payment.dto.PaymentResponse;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.fedaPay.dto.PaymentVerifyResponse;
import com.mobili.backend.module.payment.fedaPay.service.FedaPayService;
import com.mobili.backend.module.payment.service.ExchangeRateService;
import com.mobili.backend.module.payment.service.FrontendReturnUrlResolver;
import com.mobili.backend.module.payment.service.PaymentCreationService;
import com.mobili.backend.module.payment.service.PaymentGatewayResolver;
import com.mobili.backend.module.payment.service.PaymentService;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@RestController
@RequestMapping("/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentController {

    private final BookingService bookingService;
    private final FedaPayService fedaPayService;
    private final PaymentGatewayResolver paymentGatewayResolver;
    private final PaymentCreationService paymentCreationService;
    private final ExchangeRateService exchangeRateService;
    private final FrontendReturnUrlResolver frontendReturnUrlResolver;

@PostMapping("/checkout/{bookingId}")
public ResponseEntity<PaymentResponse> createCheckout(
        @PathVariable("bookingId") Long bookingId,
        @RequestBody PaymentRequest request,
        HttpServletRequest httpRequest) {
    log.info("🚀 Requête de paiement reçue pour le Booking ID: {} via {}", bookingId, request.provider());

    // Récupérer le montant métier en XOF (réel)
    var booking = bookingService.findById(bookingId);
    Long bookingAmountXof = Math.round(booking.getTotalPrice());

    // Calculer la devise cible en fonction du provider (Stripe=EUR, FedaPay=XOF)
    String targetCurrency = PaymentProvider.FEDAPAY.equals(request.provider()) ? "XOF" : "EUR";

    // Calculer montant réel dans la devise du provider
    var exchangeResult = exchangeRateService.convert(bookingAmountXof, "XOF", targetCurrency);
    Long providerAmount = exchangeResult.convertedAmount().longValue();

    // 1. Enregistrer le paiement en attente
    var payment = paymentCreationService.createPayment(
            bookingId,
            request.provider(),
            providerAmount,
            targetCurrency,
            bookingAmountXof,
            "XOF",
            exchangeResult.exchangeRate()
    );

    // 2. Résoudre le service de paiement approprié
    PaymentService paymentService = paymentGatewayResolver.resolve(request.provider());

    // 3. Créer la session
    String url = paymentService.createPaymentSession(
            bookingId,
            providerAmount,
            targetCurrency,
            request.customerEmail(),
            frontendReturnUrlResolver.resolve(httpRequest));

    return ResponseEntity.ok(new PaymentResponse(
            payment.getId(),
            bookingId,
            payment.getProvider(),
            payment.getStatus(),
            url,
            null,
            providerAmount,
            targetCurrency
    ));
}

    /**
     * Appel côté client après retour FedaPay (le webhook n'atteint souvent pas localhost en dev).
     * Relit le statut sur l'API FedaPay, puis confirme la réservation et génère les billets si approuvé.
     */
    @PostMapping("/verify/{bookingId}")
    public ResponseEntity<PaymentVerifyResponse> verifyAndConfirm(
            @PathVariable("bookingId") Long bookingId) {
        Booking booking = bookingService.findById(bookingId);
        BookingStatus st = booking.getStatus();
        if (st == BookingStatus.CONFIRMED || st == BookingStatus.COMPLETED) {
            return ResponseEntity.ok(new PaymentVerifyResponse(true, st.name()));
        }
        // PENDING (trajet public) ou AWAITING_PAYMENT (covoiturage, après
        // acceptation chauffeur) sont les deux seuls statuts d'où un paiement
        // peut encore être vérifié/confirmé.
        if (st != BookingStatus.PENDING && st != BookingStatus.AWAITING_PAYMENT) {
            return ResponseEntity.ok(new PaymentVerifyResponse(false, st.name()));
        }
        String txId = booking.getFedapayTransactionId();
        if (txId == null || txId.isBlank()) {
            // Neutre : ce champ n'est renseigné que pour un paiement FedaPay — son
            // absence est normale pour un paiement Stripe (confirmé par webhook,
            // pas par vérification active ici). Ne pas nommer "FedaPay" comme si
            // c'était systématiquement le provider utilisé.
            log.info("Pas d'ID transaction FedaPay enregistré pour bookingId={} — "
                            + "vérification active non applicable (normal hors paiement FedaPay)",
                    bookingId);
            return ResponseEntity.ok(new PaymentVerifyResponse(false, st.name()));
        }
        if (fedaPayService.isTransactionApprovedForBooking(txId)) {
            bookingService.confirmBookingAfterPayment(bookingId);
            return ResponseEntity.ok(new PaymentVerifyResponse(true, BookingStatus.CONFIRMED.name()));
        }
        return ResponseEntity.ok(new PaymentVerifyResponse(false, st.name()));
    }
}