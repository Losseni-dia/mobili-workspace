import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../../../core/network/api_client.dart';
import '../../../core/services/firebase_service.dart';

/// Diffuse la position GPS du chauffeur en temps réel vers Firestore
/// (`live_positions/{tripId}`) pendant qu'un trajet est EN_COURS — voir
/// backend LiveTrackingTokenService pour le mint du jeton Firebase et
/// firestore.rules pour les règles d'écriture (rôle "driver", bon tripId).
///
/// Point d'intégration volontairement isolé de `_StopsTabState`
/// (`trip_detail_chauffeur_page.dart`) : le bouton manuel de départ d'arrêt,
/// qui reste le flux source de vérité pour le "prochain arrêt" côté
/// passager, n'est jamais modifié — ce service ne fait qu'être démarré/
/// arrêté depuis ce flux, en parallèle, sans jamais pouvoir le bloquer
/// (toute erreur ici est avalée et journalée, jamais remontée à l'appelant).
///
/// Ajout arrivée/départ automatique par géofence (retour du test Bruxelles-
/// Lille-Paris + analyse des autres plateformes — FlixBus/BlaBlaCar Bus
/// détectent l'arrivée/le départ par GPS, pas de bouton chauffeur par
/// arrêt) : un unique géofence est posé sur l'arrêt vers lequel le véhicule
/// se dirige (voir `watchStop`), jamais sur tous les arrêts à la fois.
/// - ENTER = simple notification locale, aucune action métier.
/// - EXIT (confirmé après un court délai anti-rebond GPS) = déclenche
///   automatiquement la même action que le bouton "quitter" manuel — voir
///   `onAutoDeparture` et `_StopsTabState._handleAutoDeparture`.
/// Le bouton manuel n'est jamais retiré : c'est le fallback permanent si un
/// arrêt n'a pas de coordonnées (pas encore géocodé) ou si le géofence ne se
/// déclenche pas (zone sans GPS, itinéraire alternatif hors du rayon...).
class LiveTrackingService {
  LiveTrackingService._();

  static final LiveTrackingService instance = LiveTrackingService._();

  /// Un ID token Firebase vit 1h ; un trajet dure plus longtemps — on
  /// renouvelle bien avant l'expiration pour ne jamais couper le flux.
  static const _reauthInterval = Duration(minutes: 45);

  /// Rayon du géofence (mètres) — le minimum fiable documenté par le plugin
  /// est 200m ; on prend une marge pour absorber l'imprécision GPS urbaine
  /// et celle du géocodage (nom de ville, pas point d'arrêt exact).
  static const double _geofenceRadiusMeters = 400;

  /// Anti-rebond avant de confirmer un départ auto : un simple passage en
  /// bordure de géofence (rond-point, détour) ne doit jamais déclencher un
  /// faux départ — on revérifie la position après ce délai.
  static const Duration _exitConfirmDelay = Duration(seconds: 20);

  int? _activeTripId;
  Timer? _reauthTimer;
  bool _pluginConfigured = false;
  bool _listening = false;
  bool _geofenceListenerRegistered = false;

  String? _watchedGeofenceId;
  double? _watchedLat;
  double? _watchedLng;
  bg.Location? _lastLocation;

  /// Fourni par `_StopsTabState.start()` — jamais appelé en dehors d'un
  /// trajet EN_COURS avec tracking actif (voir `stop()` qui le vide).
  void Function(int stopIndex, String cityLabel)? _onAutoDeparture;

  bool get isTracking => _activeTripId != null;

  /// Démarre (ou redémarre sur un autre trajet) la diffusion de position.
  /// Jamais bloquant pour le flux appelant : toute erreur (réseau, jeton,
  /// permission GPS refusée) est journalée et absorbée ici.
  Future<void> start(
    int tripId, {
    void Function(int stopIndex, String cityLabel)? onAutoDeparture,
  }) async {
    if (_activeTripId == tripId) return;
    if (_activeTripId != null) {
      await stop();
    }

    try {
      await _authenticate(tripId);
      await _configurePluginOnce();

      _activeTripId = tripId;
      _onAutoDeparture = onAutoDeparture;
      if (!_listening) {
        bg.BackgroundGeolocation.onLocation(_onLocation, _onLocationError);
        _listening = true;
      }
      if (!_geofenceListenerRegistered) {
        bg.BackgroundGeolocation.onGeofence(_onGeofence);
        _geofenceListenerRegistered = true;
      }
      await bg.BackgroundGeolocation.start();

      _reauthTimer?.cancel();
      _reauthTimer = Timer.periodic(
        _reauthInterval,
        (_) => _authenticate(tripId).catchError(
          (Object e) => debugPrint('[LiveTracking] Ré-auth échouée : $e'),
        ),
      );

      debugPrint('[LiveTracking] 🚀 Démarré pour Trip #$tripId');
    } catch (e) {
      _activeTripId = null;
      _onAutoDeparture = null;
      debugPrint(
        '[LiveTracking] ⚠️ Démarrage impossible pour Trip #$tripId (le '
        'suivi manuel des arrêts continue normalement) : $e',
      );
    }
  }

  /// Arrête la diffusion — toujours appelable sans risque même si `start`
  /// n'a jamais réussi (aucune exception, aucun état requis en amont).
  Future<void> stop() async {
    final tripId = _activeTripId;
    _activeTripId = null;
    _onAutoDeparture = null;
    _reauthTimer?.cancel();
    _reauthTimer = null;
    await _clearWatchedGeofence();
    // Les callbacks onLocation/onGeofence restent enregistrés (le plugin
    // n'expose pas de désinscription ciblée pratique ici) mais deviennent
    // des no-op dès que _activeTripId repasse à null — voir _onLocation.
    try {
      await bg.BackgroundGeolocation.stop();
    } catch (e) {
      debugPrint('[LiveTracking] Erreur arrêt plugin GPS : $e');
    }
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[LiveTracking] Erreur signOut Firebase : $e');
    }
    if (tripId != null) {
      debugPrint('[LiveTracking] 🛑 Arrêté pour Trip #$tripId');
    }
  }

  /// Pose un géofence unique sur l'arrêt vers lequel le véhicule se dirige
  /// — appelé par `_StopsTabState` à chaque avancée/retour d'arrêt pendant
  /// que le tracking est actif. Remplace silencieusement le précédent
  /// géofence (jamais plusieurs actifs à la fois, un seul "prochain arrêt"
  /// à la fois). Sans coordonnées (arrêt pas encore géocodé), ne pose rien
  /// et laisse le bouton manuel comme seul moyen pour cet arrêt.
  Future<void> watchStop({
    required int stopIndex,
    required String cityLabel,
    required double? latitude,
    required double? longitude,
  }) async {
    if (_activeTripId == null) return;
    await _clearWatchedGeofence();
    if (latitude == null || longitude == null) {
      debugPrint(
        '[LiveTracking] Pas de coordonnées pour "$cityLabel" (arrêt '
        '$stopIndex) — géofence désactivé, bouton manuel uniquement.',
      );
      return;
    }
    final id = 'trip_${_activeTripId}_stop_$stopIndex';
    try {
      await bg.BackgroundGeolocation.addGeofence(bg.Geofence(
        identifier: id,
        radius: _geofenceRadiusMeters,
        latitude: latitude,
        longitude: longitude,
        notifyOnEntry: true,
        notifyOnExit: true,
        extras: {'stopIndex': stopIndex, 'cityLabel': cityLabel},
      ));
      _watchedGeofenceId = id;
      _watchedLat = latitude;
      _watchedLng = longitude;
      debugPrint('[LiveTracking] 📍 Géofence posé sur "$cityLabel" (arrêt $stopIndex)');
    } catch (e) {
      debugPrint('[LiveTracking] Impossible de poser le géofence pour "$cityLabel" : $e');
    }
  }

  Future<void> _clearWatchedGeofence() async {
    final id = _watchedGeofenceId;
    _watchedGeofenceId = null;
    _watchedLat = null;
    _watchedLng = null;
    if (id == null) return;
    try {
      await bg.BackgroundGeolocation.removeGeofence(id);
    } catch (e) {
      debugPrint('[LiveTracking] Erreur suppression géofence : $e');
    }
  }

  Future<void> _authenticate(int tripId) async {
    final response = await ApiClient.instance.dio.post<Map<String, dynamic>>(
      '/trips/$tripId/driver/live-tracking-token',
    );
    final token = response.data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Jeton de tracking absent de la réponse backend.');
    }
    await fb_auth.FirebaseAuth.instance.signInWithCustomToken(token);
  }

  /// Config posée une seule fois par run de l'app — `ready()` du plugin
  /// persiste ses réglages en natif, un second appel réinitialiserait
  /// inutilement le service natif à chaque changement de trajet.
  Future<void> _configurePluginOnce() async {
    if (_pluginConfigured) return;
    await bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 0,
        // 10-15s, fourchette actée avec l'utilisateur.
        locationUpdateInterval: 12000,
        fastestLocationUpdateInterval: 10000,
        // Continuer à émettre à l'arrêt (feu rouge, embarquement) — un
        // véhicule immobile reste une position valide pour les passagers.
        stopOnStationary: false,
        stopOnTerminate: false,
        startOnBoot: false,
        // Notification persistante obligatoire côté Android tant que le
        // service tourne en arrière-plan.
        foregroundService: true,
        enableHeadless: true,
        notification: bg.Notification(
          title: 'Mobilipro — trajet en cours',
          text: 'Votre position est partagée avec les passagers.',
        ),
      ),
    );
    _pluginConfigured = true;
  }

  void _onLocation(bg.Location location) {
    final tripId = _activeTripId;
    if (tripId == null) return;
    _lastLocation = location;
    // set() sans merge : un seul document par trajet, toujours écrasé —
    // jamais d'historique de position (voir firestore.rules).
    FirebaseFirestore.instance
        .collection('live_positions')
        .doc('$tripId')
        .set({
      'tripId': tripId,
      'lat': location.coords.latitude,
      'lng': location.coords.longitude,
      'heading': location.coords.heading,
      'speed': location.coords.speed,
      'timestamp': FieldValue.serverTimestamp(),
    }).catchError(
      (Object e) => debugPrint('[LiveTracking] Erreur écriture Firestore : $e'),
    );
  }

  void _onLocationError(bg.LocationError error) {
    // Zone sans réseau / GPS momentanément indisponible : le plugin garde
    // sa propre file locale et retente — rien à faire ici, juste tracer.
    debugPrint('[LiveTracking] Erreur position (transitoire) : $error');
  }

  void _onGeofence(bg.GeofenceEvent event) {
    if (_activeTripId == null) return;
    final extras = event.extras;
    final stopIndex = extras?['stopIndex'] as int?;
    final cityLabel = extras?['cityLabel'] as String?;
    if (stopIndex == null || cityLabel == null) return;

    if (event.action == 'ENTER') {
      debugPrint('[LiveTracking] 🏁 Arrivée détectée à "$cityLabel" (arrêt $stopIndex)');
      unawaited(FirebaseService.showLocalNotification(
        'Arrivé à $cityLabel',
        'Géofence détecté — le départ sera enregistré automatiquement en quittant la zone.',
      ));
    } else if (event.action == 'EXIT') {
      debugPrint('[LiveTracking] 🚗 Sortie détectée de "$cityLabel" (arrêt $stopIndex), confirmation en cours…');
      unawaited(_confirmAndTriggerAutoDeparture(stopIndex, cityLabel));
    }
  }

  /// Anti-rebond : un EXIT peut être un simple bruit GPS en bordure de
  /// géofence (rond-point, détour, feu rouge juste à la limite). On attend
  /// _exitConfirmDelay puis on revérifie la dernière position connue avant
  /// de déclencher réellement l'équivalent du bouton "quitter" manuel.
  Future<void> _confirmAndTriggerAutoDeparture(int stopIndex, String cityLabel) async {
    final expectedId = 'trip_${_activeTripId}_stop_$stopIndex';
    await Future.delayed(_exitConfirmDelay);

    // L'arrêt suivi a changé entre-temps (bouton manuel pressé pendant le
    // délai, undo, ou tracking arrêté) — ne jamais déclencher après coup.
    if (_watchedGeofenceId != expectedId || _onAutoDeparture == null) return;

    final last = _lastLocation;
    final lat = _watchedLat;
    final lng = _watchedLng;
    if (last != null && lat != null && lng != null) {
      final distance = _distanceMeters(
        last.coords.latitude, last.coords.longitude, lat, lng,
      );
      if (distance < _geofenceRadiusMeters) {
        // Rentré dans le rayon entre-temps — faux positif, annulé.
        debugPrint('[LiveTracking] Sortie de "$cityLabel" non confirmée (retour dans le rayon).');
        return;
      }
    }

    debugPrint('[LiveTracking] ✅ Départ automatique confirmé pour "$cityLabel" (arrêt $stopIndex)');
    _onAutoDeparture?.call(stopIndex, cityLabel);
  }

  /// Distance en mètres entre deux points GPS (formule de Haversine) — sert
  /// uniquement à confirmer un départ auto, jamais une valeur affichée.
  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMeters = 6371000.0;
    double toRad(double deg) => deg * (math.pi / 180);
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }
}
