import 'package:firebase_analytics/firebase_analytics.dart';

/// Service centralisé pour tracker les events Firebase Analytics.
/// Utilisé dans mobile_app et mobilipro.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: _analytics,
  );

  // ──────────────────────────────────────────────────────────
  // AUTH
  // ──────────────────────────────────────────────────────────

  /// Connexion réussie
  static Future<void> logLogin({String method = 'email'}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// Inscription passager réussie
  static Future<void> logRegister({String method = 'email'}) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  /// Inscription chauffeur covoiturage soumise (compte inactif)
  static Future<void> logRegisterCarpool() async {
    await _analytics.logEvent(name: 'register_carpool_submitted');
  }

  /// Déconnexion
  static Future<void> logLogout() async {
    await _analytics.logEvent(name: 'logout');
  }

  // ──────────────────────────────────────────────────────────
  // TRAJETS
  // ──────────────────────────────────────────────────────────

  /// Recherche trajet lancée
  static Future<void> logSearchTrip({
    required String from,
    required String to,
    int? seats,
  }) async {
    await _analytics.logEvent(
      name: 'search_trip',
      parameters: {'from': from, 'to': to, if (seats != null) 'seats': seats},
    );
  }

  /// Fiche trajet ouverte
  static Future<void> logViewTrip({
    required int tripId,
    required String route,
  }) async {
       await _analytics.logViewItem(
      items: [
        AnalyticsEventItem(
          itemId: tripId.toString(),
          itemName: route,
          itemCategory: 'trip',
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // RÉSERVATION & PAIEMENT (conversions clés)
  // ──────────────────────────────────────────────────────────

  /// Réservation initiée (avant paiement)
  static Future<void> logBeginBooking({
    required int tripId,
    required String route,
    required int seats,
    required double price,
  }) async {
    await _analytics.logBeginCheckout(
      value: price,
      currency: 'XOF',
      items: [
        AnalyticsEventItem(
          itemId: tripId.toString(),
          itemName: route,
          quantity: seats,
          price: price / seats,
        ),
      ],
    );
  }

  /// Paiement réussi — conversion principale
  static Future<void> logPaymentSuccess({
    required int bookingId,
    required int tripId,
    required String route,
    required int seats,
    required double amount,
  }) async {
    await _analytics.logPurchase(
      transactionId: bookingId.toString(),
      value: amount,
      currency: 'XOF',
      items: [
        AnalyticsEventItem(
          itemId: tripId.toString(),
          itemName: route,
          quantity: seats,
          price: amount / seats,
        ),
      ],
    );
  }

  /// Première réservation payée (conversion clé)
  static Future<void> logFirstBooking({required double amount}) async {
    await _analytics.logEvent(
      name: 'first_booking',
      parameters: {'value': amount, 'currency': 'XOF'},
    );
  }

  // ──────────────────────────────────────────────────────────
  // COVOITURAGE
  // ──────────────────────────────────────────────────────────

  /// Trajet covoiturage créé par le chauffeur
  static Future<void> logCreateCovoiturageTrip({
    required String route,
    required double price,
  }) async {
    await _analytics.logEvent(
      name: 'create_covoiturage_trip',
      parameters: {'route': route, 'price': price},
    );
  }

  // ──────────────────────────────────────────────────────────
  // MOBILIPRO — ADMIN / PARTENAIRE
  // ──────────────────────────────────────────────────────────

  /// Connexion pro réussie
  static Future<void> logLoginPro({required String role}) async {
    await _analytics.logLogin(loginMethod: 'pro_$role');
  }

  /// Trajet publié par un partenaire
  static Future<void> logCreateTrip({required String route}) async {
    await _analytics.logEvent(
      name: 'create_trip',
      parameters: {'route': route},
    );
  }

  /// Partenaire approuvé par l'admin
  static Future<void> logApprovePartner({required int partnerId}) async {
    await _analytics.logEvent(
      name: 'approve_partner',
      parameters: {'partner_id': partnerId},
    );
  }

  /// KYC covoiturage approuvé par l'admin
  static Future<void> logApproveKyc({required int userId}) async {
    await _analytics.logEvent(
      name: 'approve_kyc',
      parameters: {'user_id': userId},
    );
  }

  /// Export CSV effectué
  static Future<void> logExportCsv({required String type}) async {
    await _analytics.logEvent(name: 'export_csv', parameters: {'type': type});
  }

  // ──────────────────────────────────────────────────────────
  // UTILITAIRES
  // ──────────────────────────────────────────────────────────

  /// Définir l'userId Firebase (pour croiser avec les events)
  static Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  /// Définir le rôle utilisateur comme propriété
  static Future<void> setUserRole(String role) async {
    await _analytics.setUserProperty(name: 'user_role', value: role);
  }
}
