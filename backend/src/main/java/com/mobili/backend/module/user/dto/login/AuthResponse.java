package com.mobili.backend.module.user.dto.login;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {
    private String token;
    private String login;
    private Long userId;
    /** Compte gare inactif jusqu’à approbation du partenaire (inscription / nouvelle gare). */
    private Boolean accountPending;
}