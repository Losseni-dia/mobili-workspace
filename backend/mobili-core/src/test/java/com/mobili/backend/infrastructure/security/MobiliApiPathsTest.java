package com.mobili.backend.infrastructure.security;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class MobiliApiPathsTest {

    @Test
    void pathsSontCohérentsAvecLaBaseV1() {
        assertAll(
                () -> assertTrue(MobiliApiPaths.AUTH.startsWith(MobiliApiPaths.V1 + "/auth")),
                () -> assertTrue(MobiliApiPaths.TRIPS.startsWith(MobiliApiPaths.V1 + "/trips")),
                () -> assertTrue(MobiliApiPaths.PARTENAIRE.startsWith(MobiliApiPaths.V1 + "/partenaire")),
                () -> assertTrue(MobiliApiPaths.ADMIN.startsWith(MobiliApiPaths.V1 + "/admin/")),
                () -> assertTrue(MobiliApiPaths.PARTNERS.startsWith(MobiliApiPaths.V1 + "/partners")));
    }
}
