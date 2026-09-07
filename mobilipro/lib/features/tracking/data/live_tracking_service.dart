import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../../../core/network/api_client.dart';

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
class LiveTrackingService {
  LiveTrackingService._();

  static final LiveTrackingService instance = LiveTrackingService._();

  /// Un ID token Firebase vit 1h ; un trajet dure plus longtemps — on
  /// renouvelle bien avant l'expiration pour ne jamais couper le flux.
  static const _reauthInterval = Duration(minutes: 45);

  int? _activeTripId;
  Timer? _reauthTimer;
  bool _pluginConfigured = false;
  bool _listening = false;

  bool get isTracking => _activeTripId != null;

  /// Démarre (ou redémarre sur un autre trajet) la diffusion de position.
  /// Jamais bloquant pour le flux appelant : toute erreur (réseau, jeton,
  /// permission GPS refusée) est journalée et absorbée ici.
  Future<void> start(int tripId) async {
    if (_activeTripId == tripId) return;
    if (_activeTripId != null) {
      await stop();
    }

    try {
      await _authenticate(tripId);
      await _configurePluginOnce();

      _activeTripId = tripId;
      if (!_listening) {
        bg.BackgroundGeolocation.onLocation(_onLocation, _onLocationError);
        _listening = true;
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
    _reauthTimer?.cancel();
    _reauthTimer = null;
    // Le callback onLocation reste enregistré (le plugin n'expose pas de
    // désinscription ciblée pratique ici) mais devient un no-op dès que
    // _activeTripId repasse à null — voir _onLocation.
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
}
