package com.mobili.backend.module.user.entity;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.user.role.CovoiturageKycStatus;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import java.time.LocalDate;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class User extends AbstractEntity {

    private String firstname;
    private String lastname;

    @Column(unique = true, nullable = false)
    private String login; // Nom d'utilisateur unique

    @Column(unique = true, nullable = false)
    private String email;

    @Column(nullable = false)
    private String password;

    private String avatarUrl;
    private boolean enabled = true;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "user_roles", joinColumns = @JoinColumn(name = "user_id"), inverseJoinColumns = @JoinColumn(name = "role_id"))
    private Set<Role> roles = new HashSet<>();

    @OneToMany(mappedBy = "customer", cascade = CascadeType.ALL)
    private List<Booking> bookings = new ArrayList<>();

    @OneToOne(mappedBy = "owner")
    private Partner partner;

    /**
     * Compagnie d’emploi (ex. chauffeur salarié), distinct du partenaire dont cet utilisateur est
     * le <em>propriétaire</em> (relation inverse {@code Partner#owner} / {@code #partner}).
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employer_partner_id")
    private Partner employerPartner;

    /** Compte gare (responsable / équipe) : rattache l’utilisateur à une gare du partenaire. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "station_id")
    private Station station;

    /**
     * Gare d’exercice pour un <strong>chauffeur salarié</strong> (même compagnie). Distinct de {@link #station} (rôle
     * gare).
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chauffeur_affiliation_station_id")
    private Station chauffeurAffiliationStation;

    @Column(nullable = true)
    private Double balance = 0.0;

    /** Recto CNI (chauffeur covoiturage) — chemin relatif dans uploads. */
    @Column(name = "covoiturage_id_front_url")
    private String covoiturageIdFrontUrl;

    /** Verso CNI. */
    @Column(name = "covoiturage_id_back_url")
    private String covoiturageIdBackUrl;

    /** Date de fin de validité de la pièce d’identité. */
    @Column(name = "covoiturage_id_valid_until")
    private LocalDate covoiturageIdValidUntil;

    @Enumerated(EnumType.STRING)
    @Column(name = "covoiturage_kyc_status")
    private CovoiturageKycStatus covoiturageKycStatus = CovoiturageKycStatus.NONE;

    /** Véhicule déclaré à l’inscription covoiturage (hors compagnie). */
    @Column(name = "covoiturage_vehicle_brand")
    private String covoiturageVehicleBrand;

    /** Immatriculation. */
    @Column(name = "covoiturage_vehicle_plate")
    private String covoiturageVehiclePlate;

    @Column(name = "covoiturage_vehicle_color")
    private String covoiturageVehicleColor;

    @Column(name = "covoiturage_grey_card_number")
    private String covoiturageGreyCardNumber;

    @Column(name = "covoiturage_vehicle_photo_url")
    private String covoiturageVehiclePhotoUrl;

    /** Photo du conducteur (portrait) — vérification KYC. */
    @Column(name = "covoiturage_driver_photo_url")
    private String covoiturageDriverPhotoUrl;

    /**
     * Fin de période d’identité pour laquelle l’alerte « expiration dans 30 jours » a déjà été
     * envoyée (évite les doublons). Réinitialisée si l’utilisateur met à jour sa date de fin.
     */
    @Column(name = "covoiturage_kyc_expiring_notified_for")
    private LocalDate covoiturageKycExpiringNotifiedFor;

    /** Nullable pour les lignes existantes ; interpréter {@code null} comme non notifié. */
    @Column(name = "covoiturage_kyc_expired_notified")
    private Boolean covoiturageKycExpiredNotified;

    /**
     * Compte créé via l’inscription chauffeur covoiturage « grand public » (type BlaBlaCar), distinct des
     * conducteurs rattachés à une compagnie (partenaire / gare).
     * Nullable pour les lignes existantes ; interpréter {@code null} comme faux.
     */
    @Column(name = "covoiturage_solo_profile")
    private Boolean covoiturageSoloProfile;

}
