package com.mobili.backend.module.tracking.service;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStatus;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

/**
 * Mint des custom tokens Firebase scopés par trajet/rôle, pour autoriser l'accès Firestore au
 * document de position temps réel du trajet (voir firestore.rules à la racine du repo — la
 * lecture/écriture est ensuite arbitrée par Firestore lui-même via les claims du token, jamais
 * par ce backend directement). Réutilise le FirebaseApp déjà initialisé par FirebaseConfig
 * (jusqu'ici utilisé pour FCM uniquement) — pas de nouveau projet Firebase.
 *
 * IMPORTANT : les claims sont écrits via setCustomUserClaims (persistant sur le compte Firebase)
 * EN PLUS d'être passés à createCustomToken — un custom token dont les claims ne sont que dans
 * l'appel createCustomToken ne survit pas au refresh automatique de l'ID token par le SDK client
 * (le refresh régénère l'ID token à partir des claims déjà persistés sur le compte, jamais des
 * claims du jeton d'origine). Un trajet dure plus longtemps qu'un ID token (1h) : les deux apps
 * doivent re-solliciter cet endpoint et refaire signInWithCustomToken toutes les ~45 min tant que
 * l'écran de suivi est ouvert.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class LiveTrackingTokenService {

    private final TripService tripService;
    private final BookingRepository bookingRepository;

    /**
     * Le contrôle d'autorisation (chauffeur bien assigné à ce trajet) est délégué à l'appelant —
     * voir TripDriverController, protégé par assertPartnerOrGareCanOperateDriverTrip avant
     * d'appeler cette méthode, exactement comme les autres actions chauffeur du même contrôleur.
     */
    public String mintDriverToken(Long tripId, Long driverUserId) {
        String uid = "driver-" + driverUserId;
        Map<String, Object> claims = Map.of("tripId", tripId, "role", "driver");
        try {
            FirebaseAuth.getInstance().setCustomUserClaims(uid, claims);
            String token = FirebaseAuth.getInstance().createCustomToken(uid, claims);
            log.info("🚀 Jeton de tracking chauffeur créé pour Trip #{} (uid={})", tripId, uid);
            return token;
        } catch (FirebaseAuthException e) {
            log.error("💥 Échec création jeton de tracking chauffeur pour Trip #{} : {}", tripId, e.getMessage());
            throw new MobiliException(MobiliErrorCode.INTERNAL_SERVER_ERROR,
                    "Échec de préparation du suivi temps réel.");
        }
    }

    /**
     * Vérifie que le passager a une réservation active sur ce trajet (CONFIRMED/OFFLINE_SALE,
     * jamais CANCELLED/PENDING/expirée) ET que le trajet est EN_COURS (pas de tracking hors
     * service) avant de minter le jeton.
     */
    @Transactional(readOnly = true)
    public String mintPassengerToken(Long tripId, Long passengerUserId) {
        Trip trip = tripService.findById(tripId);
        if (trip.getStatus() != TripStatus.EN_COURS) {
            log.warn("⚠️ Refus jeton tracking passager : Trip #{} n'est pas EN_COURS (statut={})",
                    tripId, trip.getStatus());
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Ce trajet n'est pas en cours : suivi temps réel indisponible.");
        }

        boolean hasActiveBooking = bookingRepository.findByTripId(tripId).stream()
                .anyMatch(isActiveBookingForPassenger(passengerUserId));
        if (!hasActiveBooking) {
            log.warn("⚠️ Refus jeton tracking passager : aucune réservation active pour Trip #{} / User #{}",
                    tripId, passengerUserId);
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Aucune réservation active sur ce trajet.");
        }

        String uid = "passenger-" + passengerUserId;
        Map<String, Object> claims = Map.of("tripId", tripId, "role", "passenger");
        try {
            FirebaseAuth.getInstance().setCustomUserClaims(uid, claims);
            String token = FirebaseAuth.getInstance().createCustomToken(uid, claims);
            log.info("🚀 Jeton de tracking passager créé pour Trip #{} (uid={})", tripId, uid);
            return token;
        } catch (FirebaseAuthException e) {
            log.error("💥 Échec création jeton de tracking passager pour Trip #{} : {}", tripId, e.getMessage());
            throw new MobiliException(MobiliErrorCode.INTERNAL_SERVER_ERROR,
                    "Échec de préparation du suivi temps réel.");
        }
    }

    private java.util.function.Predicate<Booking> isActiveBookingForPassenger(Long passengerUserId) {
        return booking -> booking.getCustomer() != null
                && booking.getCustomer().getId().equals(passengerUserId)
                && (booking.getStatus() == BookingStatus.CONFIRMED
                        || booking.getStatus() == BookingStatus.OFFLINE_SALE);
    }
}
