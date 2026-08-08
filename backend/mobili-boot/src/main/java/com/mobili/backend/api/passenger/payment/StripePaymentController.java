package com.mobili.backend.api.passenger.payment;

import com.mobili.backend.module.payment.stripe.dto.StripeCheckoutRequest;
import com.mobili.backend.module.payment.stripe.service.StripeService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/payments/stripe")
@RequiredArgsConstructor
@Slf4j
public class StripePaymentController {

    private final StripeService stripeService;

    @PostMapping("/checkout/{bookingId}")
    public ResponseEntity<Map<String, String>> createCheckout(
            @PathVariable("bookingId") Long bookingId,
            @RequestBody StripeCheckoutRequest request) {
        log.info("🚀 Requête de paiement Stripe reçue pour le Booking ID: {}", bookingId);

        String url = stripeService.createCheckoutSession(
                bookingId,
                request.amount(),
                request.currency(),
                request.customerEmail());

        return ResponseEntity.ok(Map.of("paymentUrl", url));
    }

    /**
     * Page atteinte par le navigateur/WebView après un paiement Stripe réussi
     * (success_url configurée dans StripeService). La confirmation métier réelle
     * passe par le webhook Stripe (voir StripeWebhookController) — ce endpoint
     * ne fait que fournir une page de retour valide, au cas où l'app cliente
     * n'ait pas intercepté la navigation avant qu'elle n'atteigne le serveur.
     */
    @GetMapping(value = "/success", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> success(
            @RequestParam(value = "session_id", required = false) String sessionId) {
        log.info("✅ Retour navigateur succès Stripe (session_id={})", sessionId);
        return htmlPage("Paiement réussi", "Votre paiement a été accepté. Vous pouvez fermer cette fenêtre.");
    }

    /**
     * Page atteinte si l'utilisateur annule depuis la page Stripe hébergée
     * (cancel_url configurée dans StripeService), avant tout paiement.
     */
    @GetMapping(value = "/cancel", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> cancel() {
        log.info("↩️ Retour navigateur annulation Stripe");
        return htmlPage("Paiement annulé", "Vous avez annulé le paiement. Vous pouvez fermer cette fenêtre.");
    }

    private static ResponseEntity<String> htmlPage(String title, String message) {
        String html = "<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\">"
                + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
                + "<title>" + title + "</title></head>"
                + "<body style=\"font-family:sans-serif;text-align:center;padding:48px 16px;\">"
                + "<h1>" + title + "</h1><p>" + message + "</p></body></html>";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                .body(html);
    }
}
