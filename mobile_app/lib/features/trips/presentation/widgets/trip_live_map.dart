import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/config/mapbox_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/trip_provider.dart';

/// Carte de suivi temps réel du véhicule — affichée uniquement pendant
/// `trip.isInProgress` (voir `trip_detail_page.dart`). Lit le document
/// `live_positions/{tripId}` (Firestore), écrit côté chauffeur par
/// `LiveTrackingService` (mobilipro) toutes les 10-15s.
///
/// Auth Firestore : mint un jeton Firebase passager
/// (`GET /trips/{id}/live-tracking-token`, refusé si pas de réservation
/// active ou trajet pas EN_COURS — voir backend LiveTrackingTokenService)
/// puis `signInWithCustomToken`. Un ID token Firebase vit 1h : renouvelé
/// toutes les 45 min tant que ce widget reste monté.
class TripLiveMap extends ConsumerStatefulWidget {
  const TripLiveMap({super.key, required this.tripId});
  final int tripId;

  @override
  ConsumerState<TripLiveMap> createState() => _TripLiveMapState();
}

class _TripLiveMapState extends ConsumerState<TripLiveMap> {
  static const _reauthInterval = Duration(minutes: 45);

  Timer? _reauthTimer;
  Future<void>? _authFuture;
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _vehicleAnnotation;

  @override
  void initState() {
    super.initState();
    _authFuture = _authenticate();
    _reauthTimer = Timer.periodic(
      _reauthInterval,
      (_) => _authenticate().catchError(
        (Object e) => debugPrint('[TripLiveMap] Ré-auth échouée : $e'),
      ),
    );
  }

  @override
  void dispose() {
    _reauthTimer?.cancel();
    // Le jeton passager n'a aucun usage hors de cet écran — on nettoie la
    // session Firebase en quittant, comme côté chauffeur (LiveTrackingService).
    unawaited(fb_auth.FirebaseAuth.instance.signOut());
    super.dispose();
  }

  Future<void> _authenticate() async {
    try {
      final response = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/trips/${widget.tripId}/live-tracking-token',
      );
      final token = response.data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw StateError('Jeton de tracking absent de la réponse backend.');
      }
      await fb_auth.FirebaseAuth.instance.signInWithCustomToken(token);
      debugPrint('[TripLiveMap] ✅ Authentifié pour Trip #${widget.tripId}');
    } catch (e) {
      debugPrint('[TripLiveMap] ❌ Auth échouée pour Trip #${widget.tripId} : $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!MapboxConfig.isConfigured) {
      // Pas de token Mapbox fourni au build (--dart-define) : on masque la
      // carte plutôt que de planter — le reste de l'écran (ETA, arrêts)
      // continue de fonctionner normalement.
      return const SizedBox.shrink();
    }

    return FutureBuilder<void>(
      future: _authFuture,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState != ConnectionState.done) {
          return const _MapPlaceholder(child: CircularProgressIndicator());
        }
        if (authSnapshot.hasError) {
          // Jamais bloquant : réservation pas encore active, trajet pas
          // encore EN_COURS côté backend au moment du 1er rendu, etc.
          return const SizedBox.shrink();
        }
        return _buildMap();
      },
    );
  }

  Widget _buildMap() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live_positions')
          .doc('${widget.tripId}')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[TripLiveMap] ❌ Erreur stream Firestore Trip #${widget.tripId} : ${snapshot.error}');
        }
        final data = snapshot.data?.data();
        final lat = (data?['lat'] as num?)?.toDouble();
        final lng = (data?['lng'] as num?)?.toDouble();
        final timestamp = data?['timestamp'] as Timestamp?;
        debugPrint('[TripLiveMap] Snapshot Trip #${widget.tripId} : '
            'exists=${snapshot.data?.exists}, lat=$lat, lng=$lng');

        if (lat != null && lng != null) {
          // Alimente tripEtaProvider (recalcul ETA toutes les 5 min, jamais
          // à chaque position) — ref.read en dehors du cycle de build via
          // un post-frame callback, jamais pendant build().
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref
                .read(tripEtaProvider(widget.tripId).notifier)
                .updatePosition(lat, lng);
          });
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                MapWidget(
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                  onMapCreated: _onMapCreated,
                  cameraOptions: lat != null && lng != null
                      ? CameraOptions(
                          center: Point(coordinates: Position(lng, lat)),
                          zoom: 13,
                        )
                      : null,
                ),
                if (lat == null || lng == null)
                  const _MapPlaceholder(
                    child: Text(
                      'En attente de la position du véhicule…',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (timestamp != null)
                  _StalePositionBadge(timestamp: timestamp.toDate()),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    // Position déjà connue au moment où la carte finit de se créer (le
    // StreamBuilder peut avoir reçu des données avant que le natif soit prêt).
    final doc = await FirebaseFirestore.instance
        .collection('live_positions')
        .doc('${widget.tripId}')
        .get();
    final data = doc.data();
    final lat = (data?['lat'] as num?)?.toDouble();
    final lng = (data?['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      await _updateMarker(lat, lng);
    }

    FirebaseFirestore.instance
        .collection('live_positions')
        .doc('${widget.tripId}')
        .snapshots()
        .listen((snap) {
      final d = snap.data();
      final newLat = (d?['lat'] as num?)?.toDouble();
      final newLng = (d?['lng'] as num?)?.toDouble();
      if (newLat != null && newLng != null) {
        _updateMarker(newLat, newLng);
      }
    });
  }

  Future<void> _updateMarker(double lat, double lng) async {
    final manager = _pointAnnotationManager;
    final map = _mapboxMap;
    if (manager == null || map == null) return;

    final point = Point(coordinates: Position(lng, lat));
    if (_vehicleAnnotation == null) {
      _vehicleAnnotation = await manager.create(
        PointAnnotationOptions(
          geometry: point,
          iconSize: 1.4,
          textField: '🚌',
        ),
      );
    } else {
      _vehicleAnnotation!.geometry = point;
      await manager.update(_vehicleAnnotation!);
    }
    await map.flyTo(
      CameraOptions(center: point),
      MapAnimationOptions(duration: 800),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mobiliBlueFog,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle(
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray500),
        child: child,
      ),
    );
  }
}

class _StalePositionBadge extends StatelessWidget {
  const _StalePositionBadge({required this.timestamp});
  final DateTime timestamp;

  static const _staleAfter = Duration(seconds: 40);

  @override
  Widget build(BuildContext context) {
    final isStale = DateTime.now().difference(timestamp) > _staleAfter;
    if (!isStale) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_off_rounded,
                size: 14, color: AppColors.white),
            const SizedBox(width: 6),
            Text(
              'Position non actualisée',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
