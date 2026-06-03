package com.mobili.backend.infrastructure.security;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class MobiliApiPathsTest {

    @Test
    void pathsSontRelatifsAuContextPathV1() {
        assertAll(
                () -> assertEquals("/auth", MobiliApiPaths.AUTH),
                () -> assertEquals("/trips", MobiliApiPaths.TRIPS),
                () -> assertTrue(MobiliApiPaths.ADMIN.startsWith("/admin/")),
                () -> assertEquals("/partners", MobiliApiPaths.PARTNERS),
                () -> assertEquals("/v1", MobiliApiPaths.PUBLIC_API_PREFIX));
    }
}
