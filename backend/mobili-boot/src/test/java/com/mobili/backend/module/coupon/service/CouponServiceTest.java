package com.mobili.backend.module.coupon.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.coupon.entity.Coupon;
import com.mobili.backend.module.coupon.enums.CouponType;
import com.mobili.backend.module.coupon.repository.CouponRepository;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

@ExtendWith(MockitoExtension.class)
class CouponServiceTest {

    @Mock
    private CouponRepository couponRepository;

    private CouponService couponService;

    @BeforeEach
    void setUp() {
        couponService = new CouponService(couponRepository);
    }

    @Test
    void applyCoupon_percentageDiscountAppliedCorrectly() {
        when(couponRepository.findByCodeAndActiveTrue("PROMO10"))
                .thenReturn(Optional.of(coupon(CouponType.PERCENTAGE, "10", null)));

        BigDecimal finalPrice = couponService.applyCoupon("PROMO10", new BigDecimal("10000"));

        assertEquals(new BigDecimal("9000"), finalPrice);
    }

    @Test
    void applyCoupon_fixedAmountDiscountAppliedCorrectly() {
        when(couponRepository.findByCodeAndActiveTrue("MOINS2000"))
                .thenReturn(Optional.of(coupon(CouponType.FIXED_AMOUNT, "2000", null)));

        BigDecimal finalPrice = couponService.applyCoupon("MOINS2000", new BigDecimal("10000"));

        assertEquals(new BigDecimal("8000"), finalPrice);
    }

    @Test
    void applyCoupon_fixedAmountLargerThanPriceFloorsToZero() {
        when(couponRepository.findByCodeAndActiveTrue("MEGA"))
                .thenReturn(Optional.of(coupon(CouponType.FIXED_AMOUNT, "50000", null)));

        BigDecimal finalPrice = couponService.applyCoupon("MEGA", new BigDecimal("10000"));

        assertEquals(BigDecimal.ZERO, finalPrice);
    }

    @Test
    void applyCoupon_expiredCouponRejected() {
        when(couponRepository.findByCodeAndActiveTrue("PERIME"))
                .thenReturn(Optional.of(coupon(CouponType.PERCENTAGE, "10", LocalDateTime.now().minusDays(1))));

        assertThrows(IllegalArgumentException.class,
                () -> couponService.applyCoupon("PERIME", new BigDecimal("10000")));
    }

    @Test
    void applyCoupon_notFoundOrInactiveRejected() {
        when(couponRepository.findByCodeAndActiveTrue("INCONNU")).thenReturn(Optional.empty());

        assertThrows(IllegalArgumentException.class,
                () -> couponService.applyCoupon("INCONNU", new BigDecimal("10000")));
    }

    @Test
    void createCoupon_savesActiveCouponWithUppercasedCode() {
        when(couponRepository.save(any(Coupon.class))).thenAnswer(inv -> inv.getArgument(0));

        Coupon created = couponService.createCoupon(
                "  promo20  ", CouponType.PERCENTAGE, new BigDecimal("20"), null);

        assertEquals("PROMO20", created.getCode());
        assertTrue(created.isActive());
    }

    @Test
    void listCoupons_delegatesToRepositoryFindAll() {
        List<Coupon> all = List.of(coupon(CouponType.PERCENTAGE, "5", null));
        when(couponRepository.findAll()).thenReturn(all);

        assertEquals(all, couponService.listCoupons());
    }

    @Test
    void deactivateCoupon_flipsActiveFlagAndSaves() {
        Coupon existing = coupon(CouponType.FIXED_AMOUNT, "1000", null);
        existing.setActive(true);
        when(couponRepository.findById(7L)).thenReturn(Optional.of(existing));
        when(couponRepository.save(existing)).thenReturn(existing);

        Coupon result = couponService.deactivateCoupon(7L);

        assertFalse(result.isActive());
    }

    @Test
    void deactivateCoupon_unknownIdThrowsMobiliException() {
        when(couponRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(MobiliException.class, () -> couponService.deactivateCoupon(99L));
    }

    private Coupon coupon(CouponType type, String value, LocalDateTime expiresAt) {
        Coupon coupon = new Coupon();
        coupon.setType(type);
        coupon.setValue(new BigDecimal(value));
        coupon.setActive(true);
        coupon.setExpiresAt(expiresAt);
        return coupon;
    }
}
