import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
}

@riverpod
GoRouter goRouter(GoRouterRef ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.value?.isAuthenticated ?? false;
      final isOnAuthPage = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      final protectedPrefixes = [
        '/my-bookings',
        '/notifications',
        '/profile',
        '/bookings',
        '/payments',
        '/tickets',
      ];
      final needsAuth =
          protectedPrefixes.any((p) => state.matchedLocation.startsWith(p));

      if (needsAuth && !isLoggedIn) {
        return '${AppRoutes.login}?redirect=${state.uri}';
      }
      if (isLoggedIn && isOnAuthPage) {
        return AppRoutes.home;
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

      // ── Billets (hors shell, plein écran) ─────────────────
    GoRoute(
        path: AppRoutes.tickets,
        name: 'myTickets',
        builder: (_, state) => MyTicketsPage(
          filterTripId: int.tryParse(state.uri.queryParameters['tripId'] ?? ''),
        ),
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

          // Tab 2 — Mes réservations (stub)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myBookings,
                name: 'myBookings',
                builder: (_, __) => const MyBookingsPage(),
              ),
            ],
          ),

          // Tab 3 — Notifications (stub)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                name: 'notifications',
                builder: (_, __) => const _StubPage(title: 'Notifications'),
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
