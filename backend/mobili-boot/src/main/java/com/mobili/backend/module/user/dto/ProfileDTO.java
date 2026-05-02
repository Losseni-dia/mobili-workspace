package com.mobili.backend.module.user.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProfileDTO {
    private Long id;
    private String firstname;
    private String lastname;
    private String login;
    private String email;
    private String avatarUrl;
    private boolean enabled;
    private Double balance;
    private List<String> roles;
    private Long partnerId;
    /** Compte gare (responsable d’une gare) */
    private Long stationId;
    private String stationName;
    /**
     * Rôle GARE : la gare est validée (booléen {@code Station.validated}) et active, donc
     * trajets, scanner, accès compagnie autorisés. {@code null} si pas gare.
     */
    private Boolean gareOperationsEnabled;
    private Integer totalBookingsCount;

    /** NONE, PENDING, APPROVED, REJECTED, EXPIRED — chauffeur covoiturage uniquement. */
    private String covoiturageKycStatus;
    /** Fin de validité de la CNI (ISO yyyy-MM-dd), si applicable. */
    private String covoiturageIdValidUntil;
    private String covoiturageVehicleBrand;
    private String covoiturageVehiclePlate;
    private String covoiturageVehicleColor;
    private String covoiturageGreyCardNumber;
    private String covoiturageVehiclePhotoUrl;
    /** Photo portrait du conducteur (KYC covoiturage). */
    private String covoiturageDriverPhotoUrl;
    /**
     * Jours avant expiration de l’ID (négatif si dépassée). null si non applicable.
     */
    private Long covoiturageKycDaysUntilExpiry;
    private Boolean covoiturageKycExpiringWithin30Days;
    private Boolean covoiturageKycIsDocumentExpired;
    /** Inscription covoiturage grand public (non rattaché à une compagnie Mobili). */
    private Boolean covoiturageSoloProfile;
}