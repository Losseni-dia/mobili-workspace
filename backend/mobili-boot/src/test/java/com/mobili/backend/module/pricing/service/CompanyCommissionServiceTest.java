package com.mobili.backend.module.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.mobili.backend.module.pricing.dto.CommissionResult;

import org.junit.jupiter.api.Test;

class CompanyCommissionServiceTest {

    private final CompanyCommissionService service = new CompanyCommissionService();

    @Test
    void firstTicketOfMonth_isTaxedAtNinePercent() {
        // Compagnie à 0 tickets ce mois, vend 3 tickets à 5000 -> les 3 à 9%.
        CommissionResult r1 = service.calculateCommission(5000, 1);
        CommissionResult r2 = service.calculateCommission(5000, 2);
        CommissionResult r3 = service.calculateCommission(5000, 3);
        assertEquals(0.09, r1.rate());
        assertEquals(450, r1.amount());
        assertEquals(450, r2.amount());
        assertEquals(450, r3.amount());
        assertEquals(1350, r1.amount() + r2.amount() + r3.amount());
    }

    @Test
    void position500_stillInFirstTier() {
        assertEquals(0.09, service.calculateCommission(5000, 500).rate());
    }

    @Test
    void position501_switchesToSecondTier() {
        CommissionResult r = service.calculateCommission(5000, 501);
        assertEquals(0.07, r.rate());
        assertEquals(350, r.amount());
    }

    @Test
    void bookingOverlappingTierBoundary_appliesTwoDifferentRates() {
        // Compagnie à 498 tickets ce mois, vend une réservation de 4 tickets à 5000 FCFA :
        // positions 499,500 -> 9% ; positions 501,502 -> 7%. Une réservation peut donc être
        // facturée à deux taux différents si elle chevauche une frontière de palier.
        CommissionResult t499 = service.calculateCommission(5000, 499);
        CommissionResult t500 = service.calculateCommission(5000, 500);
        CommissionResult t501 = service.calculateCommission(5000, 501);
        CommissionResult t502 = service.calculateCommission(5000, 502);

        assertEquals(0.09, t499.rate());
        assertEquals(0.09, t500.rate());
        assertEquals(0.07, t501.rate());
        assertEquals(0.07, t502.rate());

        int total = t499.amount() + t500.amount() + t501.amount() + t502.amount();
        assertEquals(1600, total); // 900 (9%) + 700 (7%)
    }

    @Test
    void position1999_stillInSecondTier() {
        CommissionResult r = service.calculateCommission(5000, 1999);
        assertEquals(0.07, r.rate());
        assertEquals(350, r.amount());
    }

    @Test
    void position2000_stillInSecondTier() {
        // Ticket n°2000 : encore dans la tranche 501-2000 -> 7%.
        CommissionResult r = service.calculateCommission(5000, 2000);
        assertEquals(0.07, r.rate());
        assertEquals(350, r.amount());
    }

    @Test
    void position2001_switchesToThirdTier() {
        // Ticket n°2001 : bascule à 5%.
        CommissionResult r = service.calculateCommission(5000, 2001);
        assertEquals(0.05, r.rate());
        assertEquals(250, r.amount());
    }

    @Test
    void roundsUpToNextInteger_neverDown_neverStandardRounding() {
        // 4999 * 0.09 = 449.91 -> arrondi vers le HAUT -> 450, pas 449 (arrondi standard
        // donnerait aussi 450 ici par coïncidence, donc on vérifie aussi un cas où l'arrondi
        // standard donnerait un résultat différent de l'arrondi vers le haut).
        assertEquals(450, service.calculateCommission(4999, 1).amount());

        // 100 * 0.09 = 9.0 -> exact, aucune ambiguïté possible ; on vérifie un cas fractionnel
        // où l'arrondi standard arrondirait vers le bas alors qu'on veut vers le haut :
        // 5001 * 0.05 = 250.05 -> arrondi standard = 250, arrondi vers le haut = 251.
        assertEquals(251, service.calculateCommission(5001, 2001).amount());
    }
}
