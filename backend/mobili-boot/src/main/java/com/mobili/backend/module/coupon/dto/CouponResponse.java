package com.mobili.backend.module.coupon.dto;

import com.mobili.backend.module.coupon.entity.Coupon;
import com.mobili.backend.module.coupon.enums.CouponType;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record CouponResponse(
        Long id,
        String code,
        CouponType type,
        BigDecimal value,
        boolean active,
        LocalDateTime expiresAt) {

    public static CouponResponse from(Coupon coupon) {
        return new CouponResponse(
                coupon.getId(),
                coupon.getCode(),
                coupon.getType(),
                coupon.getValue(),
                coupon.isActive(),
                coupon.getExpiresAt());
    }
}
