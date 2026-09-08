/// Token Mapbox public (pk.*), utilisé à l'exécution pour l'affichage de la carte de
/// suivi temps réel (voir `trip_live_map.dart`). Jamais commité dans le code — transmis au
/// build via `--dart-define=MAPBOX_ACCESS_TOKEN=...` (voir `.env.example` à la racine du
/// dépôt : `MOBILEAPP_MAPBOX_ACCESS_TOKEN`, à passer à ce flag par la CI/le poste de dev).
///
/// Distinct du "downloads token" Mapbox (secret, `MAPBOX_DOWNLOADS_TOKEN`), qui ne sert qu'à
/// télécharger le SDK natif pendant le build (voir `android/build.gradle.kts`) et n'a rien à
/// faire côté Dart.
class MapboxConfig {
  MapboxConfig._();

  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  static bool get isConfigured => accessToken.isNotEmpty;
}
