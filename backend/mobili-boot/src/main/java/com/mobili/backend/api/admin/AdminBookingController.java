package com.mobili.backend.api.admin;

import com.mobili.backend.module.admin.dto.CancelBookingResponse;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Expose BookingService.cancelBooking() (déjà existante et testée, non
 * modifiée ici) via un vrai endpoint — jusqu'ici cette méthode n'était
 * appelée par aucun contrôleur. Protégé par le filtre global déjà en place
 * sur "/admin/**" (SecurityConfig.java, MobiliApiPaths.ADMIN → ROLE_ADMIN) —
 * aucune règle de sécurité supplémentaire nécessaire.
 */
@RestController
@RequestMapping("/admin/bookings")
@RequiredArgsConstructor
@Slf4j
public class AdminBookingController {

    private final BookingService bookingService;
    private final PaymentRepository paymentRepository;

    @PostMapping("/{bookingId}/cancel")
    public ResponseEntity<CancelBookingResponse> cancelBooking(@PathVariable Long bookingId) {
        // Déterminer le provider du paiement AVANT annulation : cancelBooking()
        // ne renvoie aucune information exploitable par l'UI, et ne déclenche
        // un remboursement automatique que pour Stripe.
        PaymentProvider provider = paymentRepository
                .findByBookingIdAndStatus(bookingId, PaymentStatus.SUCCESS)
                .map(Payment::getProvider)
                .orElse(null);

        bookingService.cancelBooking(bookingId);

        boolean autoRefunded = provider == PaymentProvider.STRIPE;
        String message;
        if (provider == PaymentProvider.STRIPE) {
            message = "Réservation annulée. Remboursement Stripe déclenché automatiquement.";
        } else if (provider == PaymentProvider.FEDAPAY) {
            message = "Réservation annulée. Remboursement FedaPay à traiter manuellement "
                    + "depuis le dashboard FedaPay (dashboard.fedapay.com) — aucune API de "
                    + "remboursement disponible chez ce prestataire.";
        } else {
            message = "Réservation annulée. Aucun paiement réussi trouvé pour cette "
                    + "réservation, aucun remboursement à effectuer.";
        }

        log.info("🛑 Annulation admin Booking #{} (provider={}, autoRefunded={})",
                bookingId, provider, autoRefunded);

        return ResponseEntity.ok(new CancelBookingResponse(
                bookingId,
                provider != null ? provider.name() : null,
                autoRefunded,
                message));
    }
}
