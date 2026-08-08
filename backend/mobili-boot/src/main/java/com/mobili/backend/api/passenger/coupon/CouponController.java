package com.mobili.backend.api.passenger.coupon;

import com.mobili.backend.module.coupon.service.CouponService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/coupons")
@RequiredArgsConstructor
public class CouponController {

    private final CouponService couponService;

    @GetMapping("/{code}/validate")
    public ResponseEntity<Map<String, Object>> validateCoupon(
            @PathVariable String code,
            @RequestParam BigDecimal price) {
        
        BigDecimal finalPrice = couponService.applyCoupon(code, price);
        return ResponseEntity.ok(Map.of(
                "code", code,
                "originalPrice", price,
                "finalPrice", finalPrice,
                "valid", true
        ));
    }
}
