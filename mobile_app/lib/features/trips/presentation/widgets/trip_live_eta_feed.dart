import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../providers/trip_provider.dart';

/// Alimente `tripEtaProvider(tripId)` en position temps réel, sans rendu visuel — pour les
/// endroits où on veut juste le texte "dans Y min" sans afficher une carte (ex. `TripCard` dans
/// le catalogue). Même logique d'authentification/écoute Firestore que `TripLiveMap`
/// (`trip_live_map.dart`), dupliquée volontairement ici plutôt qu'extraite en commun : les deux
/// usages ont des cycles de vie différents (une carte affichée en détail vs potentiellement
/// plusieurs cartes dans une liste scrollable), et `TripLiveMap` est un chemin déjà validé en
/// conditions réelles — pas touché pour limiter le risque de régression.
///
/// N'affiche jamais rien par elle-même : si l'auth échoue (pas de réservation active sur CE
/// trajet précis — cas normal pour un trajet d'un autre passager visible dans le catalogue),
/// `tripEtaProvider` reste simplement sans position, et l'appelant retombe sur le libellé par
/// défaut ("En route vers X" sans durée).
class TripLiveEtaFeed extends ConsumerStatefulWidget {
  const TripLiveEtaFeed({super.key, required this.tripId, required this.child});
  final int tripId;
  final Widget child;

  @override
  ConsumerState<TripLiveEtaFeed> createState() => _TripLiveEtaFeedState();
}

class _TripLiveEtaFeedState extends ConsumerState<TripLiveEtaFeed> {
  static const _reauthInterval = Duration(minutes: 45);

  Timer? _reauthTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _positionSub;

  @override
  void initState() {
    super.initState();
    unawaited(_authenticateAndListen());
    _reauthTimer = Timer.periodic(
      _reauthInterval,
      (_) => _authenticateAndListen().catchError(
        (Object e) => debugPrint('[TripLiveEtaFeed] Ré-auth échouée : $e'),
      ),
    );
  }

  @override
  void dispose() {
    _reauthTimer?.cancel();
    unawaited(_positionSub?.cancel());
    unawaited(fb_auth.FirebaseAuth.instance.signOut());
    super.dispose();
  }

  Future<void> _authenticateAndListen() async {
    try {
      final response = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/trips/${widget.tripId}/live-tracking-token',
      );
      final token = response.data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw StateError('Jeton de tracking absent de la réponse backend.');
      }
      await fb_auth.FirebaseAuth.instance.signInWithCustomToken(token);

      await _positionSub?.cancel();
      _positionSub = FirebaseFirestore.instance
          .collection('live_positions')
          .doc('${widget.tripId}')
          .snapshots()
          .listen((snapshot) {
        final data = snapshot.data();
        final lat = (data?['lat'] as num?)?.toDouble();
        final lng = (data?['lng'] as num?)?.toDouble();
        if (lat != null && lng != null && mounted) {
          ref.read(tripEtaProvider(widget.tripId).notifier).updatePosition(lat, lng);
        }
      });
    } catch (e) {
      // Le plus souvent : pas de réservation active sur ce trajet (normal pour un trajet
      // d'un autre passager visible dans le catalogue) — jamais bloquant.
      debugPrint('[TripLiveEtaFeed] Auth/écoute échouée pour Trip #${widget.tripId} : $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
