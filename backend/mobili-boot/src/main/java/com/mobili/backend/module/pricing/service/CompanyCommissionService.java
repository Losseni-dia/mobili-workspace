package com.mobili.backend.module.pricing.service;

import static com.mobili.backend.module.pricing.PricingConstants.COMMISSION_RATE_TIER_1;
import static com.mobili.backend.module.pricing.PricingConstants.COMMISSION_RATE_TIER_2;
import static com.mobili.backend.module.pricing.PricingConstants.COMMISSION_RATE_TIER_3;
import static com.mobili.backend.module.pricing.PricingConstants.COMMISSION_TIER_1_MAX;
import static com.mobili.backend.module.pricing.PricingConstants.COMMISSION_TIER_2_MAX;

import com.mobili.backend.module.pricing.dto.CommissionResult;

import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Commission compagnie — dégressive par palier de VOLUME MENSUEL, appliquée PAR TICKET
 * individuel. Barème progressif (comme un barème d'impôt), pas un seuil qui bascule tout le
 * volume au même taux : le taux d'un ticket dépend uniquement de SA position dans le compteur
 * mensuel cumulé de la compagnie, jamais du volume total du mois une fois connu.
 *
 * Fonction pure : ne connaît ni compteur, ni base de données, ni compagnie — reçoit une
 * position déjà résolue (voir PartnerMonthlyVolumeService, qui gère la réservation atomique
 * des positions) et un prix de ticket déjà calculé (transport + bagage de CE ticket, jamais
 * le forfait client, jamais Ticket.amountPaid tel quel). Règle métier distincte de
 * BookingFeeService, jamais fusionnée avec elle.
 */
@Service
public class CompanyCommissionService {

    /**
     * @param ticketPrice     tarif transport du siège + frais de bagage de CE ticket
     *                        (jamais le forfait client)
     * @param positionInMonth position (1-based) de ce ticket dans le compteur mensuel cumulé
     *                        de la compagnie — ex. le 499ᵉ ticket vendu ce mois-ci
     * @return le taux appliqué et la commission arrondie au FCFA supérieur (jamais vers le bas
     *         ni à l'arrondi standard — un forfait de 4999×0.09=449.91 devient 450, pas 449)
     */
    public CommissionResult calculateCommission(double ticketPrice, long positionInMonth) {
        double rate = rateForPosition(positionInMonth);
        // BigDecimal.valueOf(double) part de Double.toString(), donc de la représentation
        // décimale "propre" (ex. "0.07"), pas de la valeur binaire imprécise sous-jacente —
        // évite le piège classique où 5000 * 0.07 vaut 350.00000000000006 en double brut,
        // que Math.ceil arrondirait à tort à 351 au lieu de 350.
        BigDecimal raw = BigDecimal.valueOf(ticketPrice).multiply(BigDecimal.valueOf(rate));
        int amount = raw.setScale(0, RoundingMode.CEILING).intValueExact();
        return new CommissionResult(rate, amount);
    }

    private double rateForPosition(long positionInMonth) {
        if (positionInMonth <= COMMISSION_TIER_1_MAX) {
            return COMMISSION_RATE_TIER_1;
        }
        if (positionInMonth <= COMMISSION_TIER_2_MAX) {
            return COMMISSION_RATE_TIER_2;
        }
        return COMMISSION_RATE_TIER_3;
    }
}
