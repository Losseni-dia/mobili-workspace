package com.mobili.backend.api.admin;

import com.mobili.backend.module.coupon.dto.CouponResponse;
import com.mobili.backend.module.coupon.dto.CreateCouponRequest;
import com.mobili.backend.module.coupon.service.CouponService;

import jakarta.validation.Valid;

import lombok.RequiredArgsConstructor;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * CRUD admin des coupons — jusqu'ici seul GET /coupons/{code}/validate
 * existait (passager, lecture seule) ; aucune interface ne permettait de
 * créer/lister/désactiver un coupon (seule une insertion SQL directe le
 * permettait). Protégé par le filtre global "/admin/**" (ROLE_ADMIN).
 */
@RestController
@RequestMapping("/admin/coupons")
@RequiredArgsConstructor
public class AdminCouponController {

    private final CouponService couponService;

    @PostMapping
    public ResponseEntity<CouponResponse> createCoupon(@Valid @RequestBody CreateCouponRequest request) {
        var coupon = couponService.createCoupon(
                request.code(), request.type(), request.value(), request.expiresAt());
        return ResponseEntity.ok(CouponResponse.from(coupon));
    }

    @GetMapping
    public ResponseEntity<List<CouponResponse>> listCoupons() {
        var coupons = couponService.listCoupons().stream()
                .map(CouponResponse::from)
                .toList();
        return ResponseEntity.ok(coupons);
    }

    @PatchMapping("/{id}/deactivate")
    public ResponseEntity<CouponResponse> deactivateCoupon(@PathVariable Long id) {
        var coupon = couponService.deactivateCoupon(id);
        return ResponseEntity.ok(CouponResponse.from(coupon));
    }
}
