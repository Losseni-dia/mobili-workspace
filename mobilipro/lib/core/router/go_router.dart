import 'package:go_router/go_router.dart';
import 'package:mobilipro/features/admin/presentation/pages/admin_activity_logs_page.dart';
import 'package:mobilipro/features/admin/presentation/pages/admin_gestion_page.dart';
import 'package:mobilipro/features/admincom/presentation/pages/admin_com_page.dart';
import 'package:mobilipro/features/dashboard/presentation/pages/dashboard_admin_page.dart';
import 'package:mobilipro/features/dashboard/presentation/pages/dashboard_chauffeur_page.dart';
import 'package:mobilipro/features/notifications/presentation/pages/notifications_pro_page.dart';
import 'package:mobilipro/features/scanner/presentation/pages/scanner_page.dart';
import 'package:mobilipro/shared/shell/shell_admin.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_choice_page.dart';
import '../../features/auth/presentation/pages/register_company_page.dart';
import '../../features/auth/presentation/pages/register_carpool_chauffeur_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/bookings/presentation/pages/bookings_gare_page.dart';
import '../../features/canal/presentation/pages/canal_trip_page.dart';
import '../../features/covoiturage/presentation/pages/covoiturage_trip_form_page.dart';
import '../../features/chauffeurs/presentation/pages/chauffeurs_gare_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_gare_page.dart';
import '../../features/trips/presentation/pages/create_trip_page.dart';
import '../../features/trips/presentation/pages/trips_gare_page.dart';
import 'package:mobilipro/features/auth/presentation/pages/profile_page.dart';
import 'package:mobilipro/features/dashboard/presentation/pages/dashboard_partner_page.dart';
import 'package:mobilipro/features/stations/presentation/pages/partner_gare_managers_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../shared/shell/shell_chauffeur.dart';
import '../../shared/shell/shell_gare.dart';
import '../../shared/shell/shell_partner.dart';
import '../../features/partnergarecom/presentation/pages/partner_gare_com_page.dart';

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
      final isOnAuthPage =
          isOnLogin || state.matchedLocation.startsWith('/register');

      if (!isLoggedIn && !isOnAuthPage) return '/login';
      if (isLoggedIn && isOnLogin) {
        final profile = authState.value?.profile;
        if (profile == null) return '/login';
        if (profile.isChauffeur) return '/chauffeur/trips';
        if (profile.isAdmin) return '/admin/dashboard';
        if (profile.isGare) return '/gare/dashboard';
        if (profile.isPartner) return '/partner/dashboard';
        return '/gare/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),

      // ── Inscription (hors shell) ──────────────────────────────
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterChoicePage(),
        routes: [
          GoRoute(
            path: 'company',
            builder: (_, __) => const RegisterCompanyPage(),
          ),
          GoRoute(
            path: 'covoiturage',
            builder: (_, __) => const RegisterCarpoolChauffeurPage(),
          ),
        ],
      ),

      // ── Création/édition trajet covoiturage (hors shell, plein écran) ──
      // Réservé aux conducteurs covoiturage (profile.isCovoiturageDriver) ;
      // un chauffeur compagnie n'a jamais ce FAB côté dashboard.
      GoRoute(
        path: '/covoiturage/trips/new',
        builder: (_, __) => const CovoiturageTripFormPage(),
      ),
      GoRoute(
        path: '/covoiturage/trips/:tripId/edit',
        builder: (_, state) => CovoiturageTripFormPage(
          tripId: int.parse(state.pathParameters['tripId']!),
        ),
      ),

      // ── Shell GARE ─────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellGare(navigationShell: shell),
        branches: [
          // 0 — Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/dashboard',
                builder: (_, __) => const DashboardGarePage(),
              ),
            ],
          ),
          // 1 — Trajets
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/trips',
                builder: (_, __) => const TripsGarePage(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (_, __) => const CreateTripPage(),
                  ),
                  GoRoute(
                    path: 'canal/:tripId',
                    builder: (_, state) {
                      final tripId = int.parse(state.pathParameters['tripId']!);
                      final tripLabel =
                          state.uri.queryParameters['label'] ?? '';
                      return CanalTripPage(
                        tripId: tripId,
                        tripLabel: tripLabel,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // 2 — Réservations
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/bookings',
                builder: (_, __) => const BookingsGarePage(),
              ),
            ],
          ),
          // 3 — Chauffeurs
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/chauffeurs',
                builder: (_, __) => const ChauffeursGarePage(),
              ),
            ],
          ),
          // 4 — Notifications
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gare/notifications',
                builder: (_, __) => const NotificationsProPage(),
              ),
            ],
          ),
          // 5 — Profil
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

      // ── Shell CHAUFFEUR — remplace l'ancienne section dans go_router.dart ──────
      // 3 branches : Trajets (0) / Scanner (1) / Profil (2)
      // La page détail trajet + passagers est accessible via Navigator.push
      // depuis DashboardChauffeurPage (pas une branch shell)
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellChauffeur(navigationShell: shell),
        branches: [
          // 0 — Trajets (dashboard chauffeur)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chauffeur/trips',
                builder: (_, __) => const DashboardChauffeurPage(),
              ),
            ],
          ),
          // 1 — Scanner QR
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chauffeur/scanner',
                builder: (_, state) {
                  final tripId = state.uri.queryParameters['tripId'];
                  return ScannerPage(
                    tripId: tripId != null ? int.tryParse(tripId) : null,
                  );
                },
              ),
            ],
          ),
          // 2 — Profil
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chauffeur/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // ── Shell PARTNER ──────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellPartner(navigationShell: shell),
        branches: [
          // 0 — Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/dashboard',
                builder: (_, __) => const DashboardPartnerPage(),
                routes: [
                  GoRoute(
                    path: 'trips/create',
                    builder: (_, __) => const CreateTripPage(),
                  ),
                ],
              ),
            ],
          ),
          // 1 — Gestion
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/gestion',
                builder: (_, __) => const PartnerGareManagersPage(),
              ),
            ],
          ),
          // 2 — Canal société↔gares
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/canal',
                builder: (_, __) => const PartnerGareComPage(),
              ),
            ],
          ),
          // 3 — Notifications
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/notifications',
                builder: (_, __) => const NotificationsProPage(),
              ),
            ],
          ),
          // Dans le shell PARTNER — nouvelle branche Messages
         
          // 4 — Profil
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // ── Shell ADMIN — à ajouter dans go_router.dart ─────────────────────────
      // 4 branches : Dashboard / Partenaires / Utilisateurs / Profil
      // Le covoiturage est accessible via un onglet interne de AdminManagementPage,
      // ou peut devenir sa propre branche plus tard quand l'espace admin grossira.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellAdmin(navigationShell: shell),
        branches: [
          // 0 — Dashboard (stats globales — à créer)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (_, __) => const AdminDashboardPage(),
              ),
            ],
          ),
         // 1 — Gestion (partenaires + utilisateurs + covoiturage)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/gestion',
                builder: (_, __) => const AdminGestionPage(),
              ),
            ],
          ),
          // 3 — Profil
         
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/logs',
                builder: (_, __) => const AdminActivityLogsPage(),
              ),
            ],
          ),
          // Dans le shell ADMIN — nouvelle branche Messages
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/communications',
                builder: (_, __) => const AdminComPage(),
              ),
            ],
          ),
          // 4 — Notifications
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/notifications',
                builder: (_, __) => const NotificationsProPage(),
              ),
            ],
          ),
           StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
