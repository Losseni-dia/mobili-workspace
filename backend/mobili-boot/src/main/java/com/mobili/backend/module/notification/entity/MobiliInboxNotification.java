package com.mobili.backend.module.notification.entity;

import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThread;
import com.mobili.backend.module.trip.entity.Trip;
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
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "mobili_inbox_notifications")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class MobiliInboxNotification extends AbstractEntity {

    /**
     * Nullable désormais : une notification peut viser une gare (station) plutôt
     * qu'un utilisateur.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "station_id")
    private com.mobili.backend.module.station.entity.Station station;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private MobiliNotificationType type;

    @Column(nullable = false, length = 300)
    private String title;

    @Column(nullable = false, length = 2000)
    private String body;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    /**
     * Covoiturage : réservation précise concernée, pour ouvrir directement
     * la bonne carte dans "Mes réservations" plutôt que la liste entière.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id")
    private com.mobili.backend.module.booking.booking.entity.Booking booking;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "channel_message_id")
    private TripChannelMessage sourceChannelMessage;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "partner_gare_com_thread_id")
    private PartnerGareComThread partnerGareComThread;

    /**
     * Société concernée : pour permettre à l'admin d'ouvrir directement la fiche
     * (ex. nouvelle inscription).
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "partner_id")
    private com.mobili.backend.module.partner.entity.Partner partner;

    /**
     * Réclamation concernée (soumission côté admin, clôture côté passager) : pour
     * ouvrir directement la bonne réclamation plutôt que la liste entière.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_id")
    private com.mobili.backend.module.claim.entity.Claim claim;

    /**
     * Distinct de {@link #user} (destinataire) : le compte concerné par la notification
     * quand ce n'est pas celui qui la reçoit (ex. alerte KYC covoiturage envoyée aux
     * admins à propos d'un chauffeur précis).
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "subject_user_id")
    private User subjectUser;

    @Column(name = "read_at")
    private LocalDateTime readAt;

    /**
     * Différent de readAt : "vu" (badge décompté) vs "lu" (notification ouverte
     * individuellement).
     */
    @Column(name = "seen_at")
    private LocalDateTime seenAt;
}