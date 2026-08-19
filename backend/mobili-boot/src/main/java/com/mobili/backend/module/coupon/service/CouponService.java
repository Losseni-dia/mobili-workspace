package com.mobili.backend.module.coupon.service;

import com.mobili.backend.module.coupon.entity.Coupon;
import com.mobili.backend.module.coupon.enums.CouponType;
import com.mobili.backend.module.coupon.repository.CouponRepository;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

@Service
@Slf4j
@RequiredArgsConstructor
public class CouponService {

    private final CouponRepository couponRepository;

    /**
     * Création admin — le code doit être unique (contrainte DB "code" déjà
     * en place sur l'entité Coupon ; un doublon remonte en DataIntegrityViolationException,
     * déjà gérée par GlobalExceptionHandler).
     *
     * AUDIT-MOBILI.md §1.1 : code/type/value non-null déjà garantis par la validation Bean
     * sur CreateCouponRequest (@NotBlank/@NotNull/@Positive) — le bornage métier ci-dessous
     * (PERCENTAGE ≤ 100) n'est en revanche pas exprimable proprement en annotation simple,
     * donc vérifié ici explicitement plutôt que d'accepter silencieusement un coupon à 150%.
     */
    public Coupon createCoupon(String code, CouponType type, BigDecimal value, LocalDateTime expiresAt) {
        if (type == CouponType.PERCENTAGE && value.compareTo(new BigDecimal("100")) > 0) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Un coupon en pourcentage ne peut pas dépasser 100%.");
        }
        Coupon coupon = new Coupon();
        coupon.setCode(code.trim().toUpperCase());
        coupon.setType(type);
        coupon.setValue(value);
        coupon.setActive(true);
        coupon.setExpiresAt(expiresAt);
        Coupon saved = couponRepository.save(coupon);
        log.info("🎟️ Coupon créé : {} ({} {})", saved.getCode(), saved.getValue(), saved.getType());
        return saved;
    }

    public List<Coupon> listCoupons() {
        return couponRepository.findAll();
    }

    public Coupon deactivateCoupon(Long id) {
        Coupon coupon = couponRepository.findById(id)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Coupon introuvable : " + id));
        coupon.setActive(false);
        Coupon saved = couponRepository.save(coupon);
        log.info("🚫 Coupon désactivé : {}", saved.getCode());
        return saved;
    }

    /**
     * IllegalArgumentException (nu) était auparavant levée ici pour un
     * coupon invalide/expiré : GlobalExceptionHandler la route vers son
     * fallback générique (500, MOB-001), et le message serveur réel était
     * alors ignoré côté app mobile (MobiliException._localizeCode("MOB-001", ...)
     * affiche un texte générique, pas le message serveur). MobiliException
     * avec VALIDATION_ERROR (400, MOB-003) fait remonter le vrai message
     * ("Coupon invalide ou inactif" / "Coupon expiré") jusqu'à l'utilisateur.
     */
    public BigDecimal applyCoupon(String code, BigDecimal originalPrice) {
        Coupon coupon = couponRepository.findByCodeAndActiveTrue(code)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Coupon invalide ou inactif"));

        if (coupon.getExpiresAt() != null && coupon.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Coupon expiré");
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
