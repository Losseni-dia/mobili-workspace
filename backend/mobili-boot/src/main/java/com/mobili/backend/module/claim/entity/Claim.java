package com.mobili.backend.module.claim.entity;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.claim.enums.ClaimReason;
import com.mobili.backend.module.claim.enums.ClaimStatus;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/**
 * Réclamation générique — motif + réservation liée optionnelle (relation réelle, pas
 * dupliquée en JSON — voir MobiliInboxNotification pour le même pattern) + champs libres
 * propres au motif dans detailsJson (voir AppAnalyticsEvent.payload pour le même pattern).
 */
@Entity
@Table(name = "claims")
@Getter
@Setter
@NoArgsConstructor
public class Claim extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private ClaimReason reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ClaimStatus status = ClaimStatus.RECEIVED;

    /** Nullable : seuls les motifs où ClaimReason.requiresBooking() == true la renseignent. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id")
    private Booking booking;

    @Column(nullable = false, length = 2000)
    private String message;

    /** JSON brut, champs propres au motif — parsé à la volée côté service, pas d'entité dédiée. */
    @Column(name = "details_json", length = 2000)
    private String detailsJson;

    @Column(name = "admin_note", length = 2000)
    private String adminNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "handled_by_admin_id")
    private User handledBy;

    @Column(name = "resolved_at")
    private LocalDateTime resolvedAt;
}
