package com.mobili.backend.module.coupon.dto;

import com.mobili.backend.module.coupon.enums.CouponType;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Validation Bean minimale (AUDIT-MOBILI.md §1.1) : garantit que code/type/value ne sont
 * jamais null avant d'atteindre CouponService.createCoupon (évitait un NPE explicite sur
 * code.trim()). Le bornage métier de value selon le type (PERCENTAGE ≤ 100, FIXED_AMOUNT
 * positif) reste dans CouponService — pas exprimable proprement en annotation sans
 * validateur custom cross-champ pour un seul enum à 2 valeurs.
 */
public record CreateCouponRequest(
        @NotBlank(message = "Le code du coupon est obligatoire.") String code,
        @NotNull(message = "Le type de coupon est obligatoire.") CouponType type,
        @NotNull(message = "La valeur du coupon est obligatoire.")
        @Positive(message = "La valeur du coupon doit être strictement positive.") BigDecimal value,
        LocalDateTime expiresAt) {
}
