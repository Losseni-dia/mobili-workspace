import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../temp_pages.dart';

// import '../../features/auth/presentation/pages/login_page.dart';
// import '../../features/auth/presentation/pages/register_page.dart';
// import '../../features/auth/presentation/pages/register_company_page.dart';
// import '../../features/auth/presentation/pages/register_chauffeur_page.dart';
// import '../../features/auth/providers/auth_provider.dart';
// import '../../features/trips/presentation/pages/trips_list_page.dart';
// import '../../features/trips/presentation/pages/trip_detail_page.dart';
// import '../../features/trips/presentation/pages/trip_stops_page.dart';
// import '../../features/trips/presentation/pages/trip_search_page.dart';
// import '../../features/trips/presentation/pages/trip_channel_page.dart';
// import '../../features/bookings/presentation/pages/booking_create_page.dart';
// import '../../features/bookings/presentation/pages/booking_detail_page.dart';
// import '../../features/bookings/presentation/pages/my_bookings_page.dart';
// import '../../features/payments/presentation/pages/payment_webview_page.dart';
// import '../../features/payments/presentation/pages/payment_result_page.dart';
// import '../../features/tickets/presentation/pages/my_tickets_page.dart';
// import '../../features/tickets/presentation/pages/ticket_detail_page.dart';
// import '../../features/notifications/presentation/pages/notifications_page.dart';
// import '../../features/partners/presentation/pages/partners_list_page.dart';
// import '../../features/partners/presentation/pages/partner_detail_page.dart';
// import '../../features/profile/presentation/pages/profile_page.dart';
// import '../../features/shell/presentation/pages/shell_page.dart';

part 'go_router.g.dart';

// ─────────────────────────────────────────────
// Noms de routes (constantes — évite les typos)
// ─────────────────────────────────────────────
abstract class AppRoutes {
  // Auth
  static const login              = '/login';
  static const register           = '/register';
  static const registerCompany    = '/register-company';
  static const registerChauffeur  = '/register-chauffeur';

  // Shell (bottom nav)
  static const home               = '/';
  static const search             = '/search';
  static const myBookings         = '/my-bookings';
  static const notifications      = '/notifications';
  static const profile            = '/profile';

  // Trajets
  static const tripDetail         = '/trips/:tripId';
  static const tripStops          = '/trips/:tripId/stops';
  static const tripChannel        = '/trips/:tripId/channel';

  // Réservations
  static const bookingCreate      = '/trips/:tripId/book';
  static const bookingDetail      = '/bookings/:bookingId';

  // Paiement
  static const paymentWebview     = '/payments/:bookingId/checkout';
  static const paymentResult      = '/payments/:bookingId/result';

  // Tickets
  static const myTickets          = '/tickets';
  static const ticketDetail       = '/tickets/:ticketId';

  // Partenaires (publics)
  static const partners           = '/partners';
  static const partnerDetail      = '/partners/:partnerId';
}

// ─────────────────────────────────────────────
// Provider Riverpod du router
// ─────────────────────────────────────────────
@riverpod
GoRouter goRouter(GoRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,   // désactiver en prod

    // ── Redirection globale selon l'état d'auth ───────────────
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isOnAuthPage = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      // Routes protégées → login
      final protectedPrefixes = [
        '/my-bookings',
        '/notifications',
        '/profile',
        '/bookings',
        '/payments',
        '/tickets',
      ];
      final needsAuth = protectedPrefixes
          .any((p) => state.matchedLocation.startsWith(p));

      if (needsAuth && !isLoggedIn) {
        return '${AppRoutes.login}?redirect=${state.uri}';
      }
      // Déjà connecté → redir depuis auth pages
      if (isLoggedIn && isOnAuthPage) {
        return AppRoutes.home;
      }
      return null;
    },

    routes: [
      // ── Auth (sans shell) ─────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.registerCompany,
        name: 'registerCompany',
        builder: (_, __) => const RegisterCompanyPage(),
      ),
      GoRoute(
        path: AppRoutes.registerChauffeur,
        name: 'registerChauffeur',
        builder: (_, __) => const RegisterChauffeurPage(),
      ),

      // ── Partenaires publics (sans shell) ─────────────────
      GoRoute(
        path: AppRoutes.partners,
        name: 'partners',
        builder: (_, __) => const PartnersListPage(),
        routes: [
          GoRoute(
            path: ':partnerId',
            name: 'partnerDetail',
            builder: (_, state) => PartnerDetailPage(
              partnerId: int.parse(state.pathParameters['partnerId']!),
            ),
          ),
        ],
      ),

      // ── Shell (bottom navigation bar) ────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellPage(navigationShell: navigationShell),
        branches: [
          // Tab 0 — Accueil / liste trajets
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (_, __) => const TripsListPage(),
                routes: [
                  GoRoute(
                    path: 'trips/:tripId',
                    name: 'tripDetail',
                    builder: (_, state) => TripDetailPage(
                      tripId: int.parse(state.pathParameters['tripId']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'stops',
                        name: 'tripStops',
                        builder: (_, state) => TripStopsPage(
                          tripId: int.parse(state.pathParameters['tripId']!),
                        ),
                      ),
                      GoRoute(
                        path: 'channel',
                        name: 'tripChannel',
                        builder: (_, state) => TripChannelPage(
                          tripId: int.parse(state.pathParameters['tripId']!),
                        ),
                      ),
                      GoRoute(
                        path: 'book',
                        name: 'bookingCreate',
                        builder: (_, state) => BookingCreatePage(
                          tripId: int.parse(state.pathParameters['tripId']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Tab 1 — Recherche
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                name: 'search',
                builder: (_, __) => const TripSearchPage(),
              ),
            ],
          ),

          // Tab 2 — Mes réservations (protégé)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myBookings,
                name: 'myBookings',
                builder: (_, __) => const MyBookingsPage(),
                routes: [
                  GoRoute(
                    path: ':bookingId',
                    name: 'bookingDetail',
                    builder: (_, state) => BookingDetailPage(
                      bookingId: int.parse(state.pathParameters['bookingId']!),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tab 3 — Notifications (protégé)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                name: 'notifications',
                builder: (_, __) => const NotificationsPage(),
              ),
            ],
          ),

          // Tab 4 — Profil (protégé)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                builder: (_, __) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'tickets',
                    name: 'myTickets',
                    builder: (_, __) => const MyTicketsPage(),
                    routes: [
                      GoRoute(
                        path: ':ticketId',
                        name: 'ticketDetail',
                        builder: (_, state) => TicketDetailPage(
                          ticketId: int.parse(
                              state.pathParameters['ticketId']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Paiement (hors shell, flux plein écran) ───────────
      GoRoute(
        path: '/payments/:bookingId/checkout',
        name: 'paymentWebview',
        builder: (_, state) => PaymentWebviewPage(
          bookingId: int.parse(state.pathParameters['bookingId']!),
          checkoutUrl: state.uri.queryParameters['url'] ?? '',
        ),
      ),
      GoRoute(
        path: '/payments/:bookingId/result',
        name: 'paymentResult',
        builder: (_, state) => PaymentResultPage(
          bookingId: int.parse(state.pathParameters['bookingId']!),
        ),
      ),
    ],

    // ── Page 404 ─────────────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page introuvable : ${state.uri}'),
      ),
    ),
  );
}
