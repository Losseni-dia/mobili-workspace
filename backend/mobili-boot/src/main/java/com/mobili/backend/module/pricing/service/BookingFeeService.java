package com.mobili.backend.module.pricing.service;

import static com.mobili.backend.module.pricing.PricingConstants.CLIENT_FEE_HIGH;
import static com.mobili.backend.module.pricing.PricingConstants.CLIENT_FEE_HIGH_THRESHOLD;
import static com.mobili.backend.module.pricing.PricingConstants.CLIENT_FEE_LOW;
import static com.mobili.backend.module.pricing.PricingConstants.CLIENT_FEE_LOW_THRESHOLD;
import static com.mobili.backend.module.pricing.PricingConstants.CLIENT_FEE_MID;

import org.springframework.stereotype.Service;

/**
 * Forfait client — frais de service payé par le voyageur, calculé UNE SEULE FOIS par
 * réservation (jamais par ticket), sur la base de la somme des prix de tickets de cette
 * réservation, avant application du forfait lui-même (hors bagages).
 *
 * Fonction pure, sans dépendance base de données — testable indépendamment de
 * CompanyCommissionService (règle métier distincte, base de calcul différente, jamais
 * fusionnées en une seule fonction).
 */
@Service
public class BookingFeeService {

    /**
     * @param ticketsTotalAmount somme des prix de tous les tickets de la réservation
     *                           (hors bagages, avant forfait)
     * @return le forfait applicable (100/200/300 FCFA) — plafonné à 300, aucun palier
     *         supplémentaire au-delà, quel que soit le montant.
     */
    public int calculateBookingFee(double ticketsTotalAmount) {
        if (ticketsTotalAmount <= CLIENT_FEE_LOW_THRESHOLD) {
            return CLIENT_FEE_LOW;
        }
        if (ticketsTotalAmount < CLIENT_FEE_HIGH_THRESHOLD) {
            return CLIENT_FEE_MID;
        }
        return CLIENT_FEE_HIGH;
    }
}
