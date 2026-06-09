import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobilipro/features/auth/presentation/pages/profile_page.dart';
import 'package:mobilipro/features/dashboard/presentation/pages/dashboard_gare_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/shell/shell_gare.dart';
import '../../shared/shell/shell_chauffeur.dart';
import '../../shared/shell/shell_partner.dart';
import '../../shared/shell/shell_covoit.dart';

part 'go_router.g.dart';

@riverpod
GoRouter goRouter(GoRouterRef ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value?.isAuthenticated ?? false;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) {
        final profile = authState.value?.profile;
        if (profile == null) return '/login';
        // Ordre important : du plus spécifique au plus général
        if (profile.isChauffeur) return '/chauffeur/trips';
        if (profile.isGare) return '/gare/dashboard';
        if (profile.isPartner) return '/partner/dashboard';
        return '/gare/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),

      // ── Shell GARE ────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellGare(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/dashboard',
                builder: (_, __) => const DashboardGarePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/trips',
                builder: (_, __) => const _StubPage(
                  title: 'Trajets',
                  icon: Icons.directions_bus_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/bookings',
                builder: (_, __) => const _StubPage(
                  title: 'Réservations',
                  icon: Icons.bookmark_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/canal',
                builder: (_, __) => const _StubPage(
                  title: 'Canal',
                  icon: Icons.campaign_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // ── Shell CHAUFFEUR ───────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellChauffeur(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chauffeur/trips',
                builder: (_, __) => const _StubPage(
                  title: 'Mes trajets',
                  icon: Icons.directions_bus_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chauffeur/passengers',
                builder: (_, __) => const _StubPage(
                  title: 'Passagers',
                  icon: Icons.people_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chauffeur/scanner',
                builder: (_, __) => const _StubPage(
                  title: 'Scanner QR',
                  icon: Icons.qr_code_scanner_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // ── Shell PARTNER ─────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellPartner(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/dashboard',
                builder: (_, __) => const _StubPage(
                  title: 'Dashboard',
                  icon: Icons.dashboard_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/stations',
                builder: (_, __) =>
                    const _StubPage(title: 'Gares', icon: Icons.store_rounded),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/canal',
                builder: (_, __) => const _StubPage(
                  title: 'Canal',
                  icon: Icons.campaign_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // ── Shell COVOIT ──────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellCovoit(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/covoit/trips',
                builder: (_, __) => const _StubPage(
                  title: 'Mes trajets',
                  icon: Icons.directions_car_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/covoit/requests',
                builder: (_, __) => const _StubPage(
                  title: 'Demandes',
                  icon: Icons.inbox_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/covoit/revenue',
                builder: (_, __) => const _StubPage(
                  title: 'Revenus',
                  icon: Icons.payments_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/covoit/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _StubPage extends StatelessWidget {
  const _StubPage({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF1B2A6B)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2A6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'En construction...',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    ),
  );
}
