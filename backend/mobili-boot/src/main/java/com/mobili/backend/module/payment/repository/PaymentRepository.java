package com.mobili.backend.module.payment.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;

import java.util.List;
import java.util.Optional;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    Optional<Payment> findByExternalReference(String externalReference);
    Optional<Payment> findByBookingIdAndProvider(Long bookingId, PaymentProvider provider);
    Optional<Payment> findByBookingIdAndExternalReference(Long bookingId, String externalReference);

    /**
     * AUDIT-MOBILI.md §1.3 : findByBookingIdAndProvider (Optional, résultat unique attendu)
     * pouvait lever IncorrectResultSizeDataAccessException si un paiement Stripe avait
     * échoué puis été retenté avec succès (2 lignes Payment provider=STRIPE pour la même
     * réservation), et ne filtrait de toute façon pas sur le statut — risquait de
     * rembourser via l'externalReference d'un paiement FAILED/PENDING. Filtré sur SUCCESS et
     * trié par id décroissant : triggerRefund (BookingService) prend le plus récent paiement
     * Stripe réellement réussi.
     */
    List<Payment> findAllByBookingIdAndProviderAndStatusOrderByIdDesc(
            Long bookingId, PaymentProvider provider, PaymentStatus status);

    /**
     * Même usage que findAllByBookingIdAndProviderAndStatusOrderByIdDesc, mais accepte aussi
     * REFUNDED — un paiement déjà partiellement remboursé (annulation ciblée d'une partie des
     * tickets d'une réservation à plusieurs sièges) doit rester trouvable pour un remboursement
     * SUIVANT sur la même réservation. Sans ça, une 2e annulation partielle (Booking déjà passé
     * REFUNDED après la 1re) ne retrouvait plus aucun paiement Stripe : triggerRefund
     * (BookingService) l'ignorait silencieusement, et l'argent des tickets annulés ensuite
     * n'était jamais reversé au client (incident constaté en prod le 2026-09-02 — voir aussi
     * PaymentRefundService.refund, qui doit accepter SUCCESS et REFUNDED pour la même raison).
     */
    List<Payment> findAllByBookingIdAndProviderAndStatusInOrderByIdDesc(
            Long bookingId, PaymentProvider provider, List<PaymentStatus> statuses);

    /**
     * Détermine le provider d'un paiement pour l'affichage admin (message de remboursement),
     * même élargissement que ci-dessus : un paiement déjà REFUNDED (remboursement partiel
     * antérieur) doit toujours être retrouvé, sinon l'admin voit à tort "aucun paiement lié à
     * cette réservation" sur toute annulation suivant la première (incident 2026-09-02).
     */
    Optional<Payment> findFirstByBookingIdAndStatusInOrderByIdDesc(
            Long bookingId, List<PaymentStatus> statuses);

    /**
     * Utilisé pour retrouver le paiement en cours AVANT que son externalReference
     * n'ait jamais été écrit (webhook Stripe ET callback FedaPay recevant l'ID de
     * transaction pour la première fois — voir
     * PaymentStatusUpdateService.markAsSuccessWithReference, appelée par les deux).
     * bookingId seul n'est pas fiable : plusieurs Payment peuvent exister pour la
     * même réservation (tentatives précédentes échouées/annulées, autre provider).
     * Pas de filtre sur le provider ici : PENDING est déjà garanti unique par
     * bookingId, tous providers confondus (PaymentCreationService refuse la
     * création d'un deuxième paiement PENDING pour une même réservation).
     */
    Optional<Payment> findByBookingIdAndStatus(Long bookingId, PaymentStatus status);
}
