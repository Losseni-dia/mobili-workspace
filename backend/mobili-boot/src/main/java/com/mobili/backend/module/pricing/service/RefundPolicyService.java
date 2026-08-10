package com.mobili.backend.module.pricing.service;

import com.mobili.backend.module.booking.booking.entity.Booking;

import org.springframework.stereotype.Service;

/**
 * Point d'extension pour une future politique de remboursement (chantier séparé, hors scope
 * ici). Pour l'instant, seule règle actée : le forfait client n'est JAMAIS remboursable, quelle
 * que soit la raison de l'annulation. Cette méthode n'est appelée nulle part encore — elle
 * existe pour que la politique de remboursement réelle (montant effectivement restitué via
 * Stripe/FedaPay) s'y branche plus tard sans dupliquer la règle "forfait non remboursable".
 */
@Service
public class RefundPolicyService {

    /**
     * @return le montant remboursable si l'intégralité du reste (hors forfait) était
     *         remboursée — ne préjuge d'aucune politique de remboursement partiel, juste de
     *         la non-remboursabilité du forfait.
     */
    public double calculateRefundableAmount(Booking booking) {
        double serviceFee = booking.getServiceFee() != null ? booking.getServiceFee() : 0;
        return booking.getTotalPrice() - serviceFee;
    }
}
