package com.mobili.backend.module.tracking.service;

import com.google.firebase.auth.AuthErrorCode;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.UserRecord;

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

    /**
     * Le contrôle d'autorisation (chauffeur bien assigné à ce trajet) est délégué à l'appelant —
     * voir TripDriverController, protégé par assertPartnerOrGareCanOperateDriverTrip avant
     * d'appeler cette méthode, exactement comme les autres actions chauffeur du même contrôleur.
     */
    public String mintDriverToken(Long tripId, Long driverUserId) {
        String uid = "driver-" + driverUserId;
        // tripId en String (pas Long) : firestore.rules compare request.auth.token.tripId à
        // {tripId}, le segment de chemin du document — toujours une chaîne côté Firestore. Un
        // claim numérique ne serait jamais égal à cette chaîne (pas de coercition implicite
        // dans le langage des règles), bloquant silencieusement lecture/écriture malgré un
        // jeton par ailleurs valide.
        Map<String, Object> claims = Map.of("tripId", String.valueOf(tripId), "role", "driver");
        try {
            setClaimsCreatingUserIfNeeded(uid, claims);
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
     * Vérifie uniquement que le trajet est EN_COURS (pas de tracking hors service) avant de
     * minter le jeton — délibérément PAS de vérification de réservation active sur ce trajet
     * précis : n'importe quel utilisateur connecté à l'app peut suivre un trajet en cours (ex.
     * un proche qui veut voir où se trouve le véhicule d'un voyageur, sans avoir lui-même acheté
     * de billet). L'authentification (compte Mobili requis) reste appliquée en amont par Spring
     * Security sur ce endpoint — voir TripReadController.getLiveTrackingToken.
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

        String uid = "passenger-" + passengerUserId;
        // Même remarque que mintDriverToken : tripId en String pour matcher le segment de
        // chemin Firestore dans firestore.rules.
        Map<String, Object> claims = Map.of("tripId", String.valueOf(tripId), "role", "passenger");
        try {
            setClaimsCreatingUserIfNeeded(uid, claims);
            String token = FirebaseAuth.getInstance().createCustomToken(uid, claims);
            log.info("🚀 Jeton de tracking passager créé pour Trip #{} (uid={})", tripId, uid);
            return token;
        } catch (FirebaseAuthException e) {
            log.error("💥 Échec création jeton de tracking passager pour Trip #{} : {}", tripId, e.getMessage());
            throw new MobiliException(MobiliErrorCode.INTERNAL_SERVER_ERROR,
                    "Échec de préparation du suivi temps réel.");
        }
    }

    /**
     * setCustomUserClaims exige que l'utilisateur Firebase existe déjà (contrairement à
     * createCustomToken, qui accepte n'importe quel uid) — la toute première fois qu'un chauffeur
     * ou passager démarre le suivi temps réel, cet uid ("driver-{id}"/"passenger-{id}") n'existe
     * pas encore côté Firebase et l'appel échoue avec USER_NOT_FOUND. On le crée alors à la volée
     * avant de réessayer — idempotent, les appels suivants pour le même uid passent directement.
     */
    private void setClaimsCreatingUserIfNeeded(String uid, Map<String, Object> claims) throws FirebaseAuthException {
        try {
            FirebaseAuth.getInstance().setCustomUserClaims(uid, claims);
        } catch (FirebaseAuthException e) {
            if (e.getAuthErrorCode() != AuthErrorCode.USER_NOT_FOUND) {
                throw e;
            }
            log.info("ℹ️ Utilisateur Firebase {} inexistant — création avant mint du jeton.", uid);
            FirebaseAuth.getInstance().createUser(new UserRecord.CreateRequest().setUid(uid));
            FirebaseAuth.getInstance().setCustomUserClaims(uid, claims);
        }
    }
}
