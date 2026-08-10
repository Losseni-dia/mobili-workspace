package com.mobili.backend.module.claim.dto;

import com.mobili.backend.module.claim.enums.ClaimReason;

import java.util.Map;

/**
 * [bookingId] : obligatoire si reason.requiresBooking() (voir ClaimReason), ignoré sinon.
 * [details] : champs libres propres au motif (ex. LOST_ITEM : {"lostItemDescription": "..."}),
 * sérialisés tels quels dans Claim.detailsJson — aucune validation de structure ici, le motif
 * décide de ce qu'il en fait à l'affichage (MobiliPro), pas le backend.
 */
public record CreateClaimRequest(
        ClaimReason reason,
        Long bookingId,
        String message,
        Map<String, String> details) {
}
