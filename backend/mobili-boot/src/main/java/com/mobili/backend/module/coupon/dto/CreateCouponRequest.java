package com.mobili.backend.module.coupon.dto;

import com.mobili.backend.module.coupon.enums.CouponType;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record CreateCouponRequest(
        String code,
        CouponType type,
        BigDecimal value,
        LocalDateTime expiresAt) {
}
