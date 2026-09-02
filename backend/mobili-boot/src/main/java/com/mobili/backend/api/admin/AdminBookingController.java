package com.mobili.backend.api.admin;

import com.mobili.backend.module.admin.dto.CancelBookingResponse;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

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
        // SUCCESS et REFUNDED tous les deux acceptés : un paiement déjà partiellement remboursé
        // (annulation antérieure d'une partie des tickets de cette réservation) doit rester
        // détectable, sinon l'admin voit à tort "aucun paiement lié à cette réservation" sur
        // toute annulation suivant la première (incident 2026-09-02).
        PaymentProvider provider = paymentRepository
                .findFirstByBookingIdAndStatusInOrderByIdDesc(
                        bookingId, List.of(PaymentStatus.SUCCESS, PaymentStatus.REFUNDED))
                .map(Payment::getProvider)
                .orElse(null);

        double refunded = bookingService.cancelBooking(bookingId);

        boolean autoRefunded = provider == PaymentProvider.STRIPE;
        String message = buildRefundMessage(provider, "Réservation annulée.", refunded);

        log.info("🛑 Annulation admin Booking #{} (provider={}, autoRefunded={}, montant={})",
                bookingId, provider, autoRefunded, refunded);

        return ResponseEntity.ok(new CancelBookingResponse(
                bookingId,
                provider != null ? provider.name() : null,
                autoRefunded,
                message,
                refunded));
    }

    /**
     * Annulation ciblée de tickets d'UNE réservation (annulation partielle demandée via
     * réclamation, exécutée après review admin — voir Claim.detailsJson côté ClaimService).
     * Le forfait client n'est jamais remboursé, ni ici ni sur /cancel — voir
     * BookingService.computeRefundableAmount.
     */
    @PostMapping("/{bookingId}/cancel-tickets")
    public ResponseEntity<CancelBookingResponse> cancelTickets(
            @PathVariable Long bookingId, @RequestBody List<Long> ticketIds) {
        // AUDIT-MOBILI.md §1.1 : List<Long> brut, aucune contrainte de taille/format
        // auparavant — un corps vide/null n'était pas rejeté explicitement. Vérification
        // manuelle plutôt que @Validated + @NotEmpty sur le paramètre : GlobalExceptionHandler
        // ne gère aujourd'hui que MethodArgumentNotValidException (@Valid sur un objet), pas
        // ConstraintViolationException (contrainte directe sur un paramètre de méthode) — un
        // ticketIds vide serait retombé sur le fallback générique 500 plutôt qu'un vrai 400.
        if (ticketIds == null || ticketIds.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Aucun ticket à annuler.");
        }

        // SUCCESS et REFUNDED tous les deux acceptés : un paiement déjà partiellement remboursé
        // (annulation antérieure d'une partie des tickets de cette réservation) doit rester
        // détectable, sinon l'admin voit à tort "aucun paiement lié à cette réservation" sur
        // toute annulation suivant la première (incident 2026-09-02).
        PaymentProvider provider = paymentRepository
                .findFirstByBookingIdAndStatusInOrderByIdDesc(
                        bookingId, List.of(PaymentStatus.SUCCESS, PaymentStatus.REFUNDED))
                .map(Payment::getProvider)
                .orElse(null);

        double refunded = bookingService.cancelTickets(bookingId, ticketIds);

        boolean autoRefunded = provider == PaymentProvider.STRIPE && refunded > 0;
        String message = buildRefundMessage(
                provider, ticketIds.size() + " ticket(s) annulé(s).", refunded);

        log.info("🛑 Annulation admin tickets {} (Booking #{}, provider={}, autoRefunded={}, montant={})",
                ticketIds, bookingId, provider, autoRefunded, refunded);

        return ResponseEntity.ok(new CancelBookingResponse(
                bookingId,
                provider != null ? provider.name() : null,
                autoRefunded,
                message,
                refunded));
    }

    /**
     * Rattrapage ponctuel — à appeler une fois après déploiement du correctif de
     * BookingService.createOfflineSale() (aucun Ticket n'était généré pour les ventes guichet
     * avant ce fix). Idempotent : ne retraite jamais une réservation qui a déjà un ticket, donc
     * sans risque à rappeler plusieurs fois par erreur.
     */
    @PostMapping("/backfill-offline-sale-tickets")
    public ResponseEntity<java.util.Map<String, Object>> backfillOfflineSaleTickets() {
        int fixed = bookingService.backfillMissingOfflineSaleTickets();
        log.info("🎫 Rattrapage tickets guichet déclenché depuis l'admin : {} résa(s) corrigée(s).", fixed);
        return ResponseEntity.ok(java.util.Map.of("bookingsFixed", fixed));
    }

    /**
     * Rattrapage ponctuel (incident 2026-09-02) : retire le forfait de service client des
     * ventes guichet créées avant le correctif de BookingService.createOfflineSale. Idempotent,
     * voir sa Javadoc — sans risque à rappeler plusieurs fois.
     */
    @PostMapping("/backfill-offline-sale-service-fee")
    public ResponseEntity<java.util.Map<String, Object>> backfillOfflineSaleServiceFee() {
        int fixed = bookingService.backfillOfflineSaleServiceFee();
        log.info("💰 Rattrapage forfait guichet déclenché depuis l'admin : {} résa(s) corrigée(s).", fixed);
        return ResponseEntity.ok(java.util.Map.of("bookingsFixed", fixed));
    }

    private String buildRefundMessage(PaymentProvider provider, String prefix, double refunded) {
        if (provider == PaymentProvider.STRIPE) {
            return prefix + " Remboursement Stripe de " + Math.round(refunded)
                    + " FCFA déclenché automatiquement (forfait de service exclu).";
        } else if (provider == PaymentProvider.FEDAPAY) {
            return prefix + " Remboursement FedaPay de " + Math.round(refunded)
                    + " FCFA à traiter manuellement depuis le dashboard FedaPay "
                    + "(dashboard.fedapay.com) — aucune API de remboursement disponible chez "
                    + "ce prestataire. Forfait de service exclu de ce montant.";
        }
        return prefix + " Aucun paiement réussi trouvé pour cette réservation, aucun "
                + "remboursement à effectuer.";
    }
}
