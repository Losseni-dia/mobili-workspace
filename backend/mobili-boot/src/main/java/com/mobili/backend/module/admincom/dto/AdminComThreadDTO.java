package com.mobili.backend.module.admincom.dto;

import java.time.LocalDateTime;

public record AdminComThreadDTO(
                Long id,
                String subject,
                String type, // PARTNER | COVOITURAGE | SUPPORT

                // Côté admin
                Long adminUserId,
                String adminUserName,

                // Côté partenaire/chauffeur/client
                Long partnerUserId,
                String partnerUserName, // nom complet (dirigeant, chauffeur, ou client)
                String companyName, // nom société (si PARTNER, sinon null)
                String displayLabel, // label affiché dans la liste (ex: "Transco CI — Jean Koné")

                LocalDateTime lastActivityAt,
                String lastActivityAtFormatted) {
}