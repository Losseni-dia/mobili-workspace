package com.mobili.backend.module.coupon.service;

import com.mobili.backend.module.coupon.entity.Coupon;
import com.mobili.backend.module.coupon.enums.CouponType;
import com.mobili.backend.module.coupon.repository.CouponRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;

@Service
@Slf4j
@RequiredArgsConstructor
public class CouponService {

    private final CouponRepository couponRepository;

    public BigDecimal applyCoupon(String code, BigDecimal originalPrice) {
        Coupon coupon = couponRepository.findByCodeAndActiveTrue(code)
                .orElseThrow(() -> new IllegalArgumentException("Coupon invalide ou inactif"));

        if (coupon.getExpiresAt() != null && coupon.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new IllegalArgumentException("Coupon expiré");
        }

        BigDecimal discount = BigDecimal.ZERO;
        if (coupon.getType() == CouponType.PERCENTAGE) {
            discount = originalPrice.multiply(coupon.getValue()).divide(new BigDecimal("100"), 0, RoundingMode.HALF_UP);
        } else if (coupon.getType() == CouponType.FIXED_AMOUNT) {
            discount = coupon.getValue();
        }

        BigDecimal finalPrice = originalPrice.subtract(discount);
        return finalPrice.compareTo(BigDecimal.ZERO) < 0 ? BigDecimal.ZERO : finalPrice;
    }
}
