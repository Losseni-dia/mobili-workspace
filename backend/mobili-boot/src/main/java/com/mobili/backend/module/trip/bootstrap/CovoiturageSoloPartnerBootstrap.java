package com.mobili.backend.module.trip.bootstrap;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.repository.PartnerRepository;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Partenaire technique unique pour raccrocher les offres covoiturage « solo » (DB exige
 * {@code partner_id}).
 */
@Component
@Order(20)
@RequiredArgsConstructor
@Slf4j
public class CovoiturageSoloPartnerBootstrap implements ApplicationRunner {

    /** Code d’inscription factice, stable, pour retrouver l’enregistrement. Max 12 car. ({@code Partner#registrationCode}). */
    public static final String POOL_REGISTRATION_CODE = "MOBICOVITU01";
    private static final String POOL_EMAIL = "covoiturage.pool@mobili.internal";

    private final PartnerRepository partnerRepository;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (partnerRepository.findByRegistrationCodeIgnoreCase(POOL_REGISTRATION_CODE).isPresent()) {
            return;
        }
        Partner p = new Partner();
        p.setName("Covoiturage particuliers (Mobili)");
        p.setEmail(POOL_EMAIL);
        p.setEnabled(true);
        p.setRegistrationCode(POOL_REGISTRATION_CODE);
        p.setPhone("");
        p.setBusinessNumber("MOBILI-COV-POOL");
        p.setCovoiturageSoloPool(true);
        partnerRepository.save(p);
        log.info("Partenaire technique covoiturage solo créé (code={}).", POOL_REGISTRATION_CODE);
    }

    public Partner getPoolPartner() {
        return partnerRepository
                .findByRegistrationCodeIgnoreCase(POOL_REGISTRATION_CODE)
                .orElseThrow(
                        () -> new MobiliException(
                                MobiliErrorCode.INTERNAL_SERVER_ERROR,
                                "Partenaire pool covoiturage introuvable. Redémarrez l'application."));
    }
}
