import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobili/features/covoiturage/presentation/pages/covoiturage_bookings_list_page.dart';
import 'package:mobili/features/covoiturage/providers/covoiturage_provider.dart';
import 'package:mobili/features/legal/presentation/cgu_page.dart';
import 'package:mobili/features/legal/presentation/confidentialite_page.dart';
import 'package:mobili/features/notifications/presentation/notifications_page.dart';
import 'package:mobili/features/notifications/presentation/trip_channel_thread_page.dart';
import 'package:mobili/features/profile/presentation/edit_profile_page.dart';
import 'package:mobili/features/support/presentation/pages/support_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/widgets/mobili_error_widget.dart';
import '../../shared/shell/shell_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/trips/presentation/pages/trips_list_page.dart';
import '../../features/trips/presentation/pages/trip_detail_page.dart';
import '../../features/trips/presentation/pages/trip_search_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/bookings/presentation/pages/my_tickets_page.dart';
import '../../features/bookings/presentation/pages/my_bookings_page.dart';
import '../../features/covoiturage/presentation/pages/covoiturage_entry_page.dart';
import '../../features/covoiturage/presentation/pages/covoiturage_register_page.dart';
import '../../features/covoiturage/presentation/pages/covoiturage_apply_page.dart';
import '../../features/covoiturage/presentation/pages/covoiturage_profile_page.dart';
import '../../features/covoiturage/presentation/pages/covoiturage_dashboard_page.dart';
import '../../features/covoiturage/presentation/pages/covoiturage_trip_form_page.dart';
import '../../features/covoiturage/presentation/pages/covoiturage_trip_detail_page.dart';
import '../../features/trips/domain/models/trip.dart';

part 'go_router.g.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/';
  static const search = '/search';
  static const myBookings = '/my-bookings';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const tickets = '/tickets';
  static const covoiturage = '/covoiturage';
}

/// Notifie GoRouter de ré-évaluer son `redirect` quand authProvider change,
/// SANS jamais recréer l'objet GoRouter (ce qui ferait perdre la page
/// actuelle et repartir sur initialLocation à chaque changement d'état).
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

@Riverpod(keepAlive: true)
GoRouter goRouter(GoRouterRef ref) {
  final refreshListenable = _AuthRouterRefresh(ref);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.value?.isLoading == true) return null;
      if (authState.value?.status == AuthStatus.initial) return null;

      final isLoggedIn = authState.value?.isAuthenticated ?? false;
      final isOnAuthPage = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      if (isOnAuthPage) return null;

      final protectedPrefixes = [
        '/my-bookings',
        '/notifications',
        '/profile',
        '/edit-profile',
        '/bookings',
        '/payments',
        '/tickets',
        '/covoiturage/profile',
        '/covoiturage/trips',
        '/covoiturage/history',
        '/covoiturage/apply',
      ];
      final needsAuth =
          protectedPrefixes.any((p) => state.matchedLocation.startsWith(p));

      if (needsAuth && !isLoggedIn) {
        return '${AppRoutes.login}?redirect=${state.uri}';
      }

      return null;
    },


    routes: [
      // ── Auth ──────────────────────────────────────────────
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
        path: '/cgu',
        builder: (_, __) => const CguPage(),
      ),
      GoRoute(
        path: '/confidentialite',
        builder: (_, __) => const ConfidentialitePage(),
      ),
      GoRoute(
        path: '/support',
        builder: (_, __) => const SupportPage(),
      ),

    // ── Fil de discussion trajet (hors shell, plein écran, lecture seule) ──
      GoRoute(
        path: '/trips/:tripId/channel',
        name: 'tripChannelThread',
        builder: (_, state) => TripChannelThreadPage(
          tripId: int.parse(state.pathParameters['tripId']!),
          tripLabel: state.uri.queryParameters['label'] ?? '',
        ),
      ),

      // ── Covoiturage (hors shell, plein écran) ─────────────
  // ── Mes réservations (hors shell, plein écran) ─────────
      GoRoute(
        path: AppRoutes.myBookings,
        name: 'myBookings',
        builder: (_, __) => const MyBookingsPage(),
      ),
      // ── Covoiturage (hors shell, plein écran) ─────────────
      GoRoute(
        path: AppRoutes.covoiturage,
        name: 'covoiturage',
        builder: (_, __) => const CovoiturageEntryPage(),
        routes: [
          GoRoute(
            path: 'register',
            name: 'covoiturageRegister',
            builder: (_, __) => const CovoiturageRegisterPage(),
          ),
          GoRoute(
            path: 'apply',
            name: 'covoiturageApply',
            builder: (_, __) => const CovoiturageApplyPage(),
          ),
          GoRoute(
            path: 'profile',
            name: 'covoiturageProfile',
            builder: (_, __) => const CovoiturageProfilePage(),
          ),
          GoRoute(
            path: 'trips',
            name: 'covoiturageTrips',
            builder: (_, __) => const CovoiturageDashboardPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'covoiturageTripNew',
                builder: (_, __) => const CovoiturageTripFormPage(),
              ),
              GoRoute(
                path: ':tripId/edit',
                name: 'covoiturageTripEdit',
                builder: (_, state) => CovoiturageTripFormPage(
                  trip: state.extra as Trip?,
                ),
              ),
              GoRoute(
                path: ':tripId/detail',
                name: 'covoiturageTripDetail',
                builder: (_, state) => CovoiturageTripDetailPage(
                  trip: state.extra as Trip,
                ),
              ),
            ],
          ),
         GoRoute(
            path: 'history',
            name: 'covoiturageHistory',
            builder: (_, state) => CovoiturageHistoryPage(
              trips: (state.extra as List<Trip>?) ?? const [],
            ),
          ),
          GoRoute(
            path: 'all-trips',
            name: 'covoiturageAllTrips',
            builder: (_, state) => CovoiturageHistoryPage(
              trips: (state.extra as List<Trip>?) ?? const [],
              title: 'Tous mes trajets',
              emptyLabel: 'Aucun trajet publié',
            ),
            
          ),
          GoRoute(
            path: 'bookings',
            name: 'covoiturageBookings',
            builder: (_, state) => CovoiturageBookingsListPage(
              bookings:
                  (state.extra as List<PartnerRecentBooking>?) ?? const [],
            ),
          ),
        ],
      ),

      // ── Shell ──────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellPage(navigationShell: navigationShell),
        branches: [
          // Tab 0 — Accueil
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
                  ),
                ],
              ),
            ],
          ),

        // Tab 1 — Mes tickets
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tickets,
                name: 'myTicketsTab',
                builder: (_, __) => const MyTicketsPage(),
              ),
            ],
          ),
          // Tab 3 — Notifications
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                name: 'notifications',
                builder: (_, __) => const NotificationsPage(),
              ),
            ],
          ),

          // Tab 4 — Profil
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                builder: (_, __) => const ProfilePage(),
              ),
              GoRoute(
                path: '/edit-profile',
                builder: (_, __) => const EditProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: MobiliErrorWidget(
        error: MobiliErrorData(
          errorCode: 'MOB-002',
          message: 'La page ${state.uri} est introuvable.',
        ),
      ),
    ),
  );
}

class _StubPage extends StatelessWidget {
  final String title;
  const _StubPage({required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text(title,
              style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ),
      );
}
