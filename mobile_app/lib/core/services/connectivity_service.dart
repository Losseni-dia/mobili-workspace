import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True si au moins un type de connexion est actif — connectivity_plus ^6 émet une
/// `List<ConnectivityResult>` (plusieurs interfaces possibles : wifi + mobile en même
/// temps sur certains appareils), `[ConnectivityResult.none]` signifiant hors ligne.
bool _hasConnection(List<ConnectivityResult> results) =>
    results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);

/// État réseau réactif — émet immédiatement l'état courant puis à chaque changement.
///
/// AUDIT-MOBILI.md §3.4 : connectivity_plus était déclaré en dépendance
/// ("détection réseau (offline UX)") mais jamais utilisé nulle part dans `lib/` — la
/// gestion "hors ligne" reposait uniquement sur le timeout Dio (30s) côté
/// `_ErrorInterceptor`, sans retour proactif avant l'appel réseau. Utilisé par
/// [OfflineBannerOverlay] (shared/widgets/offline_banner.dart) pour afficher une
/// bannière dès la perte de connectivité, sans attendre qu'une requête échoue.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _hasConnection(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_hasConnection);
});
