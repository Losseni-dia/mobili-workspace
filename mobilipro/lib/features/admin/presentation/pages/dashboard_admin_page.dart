import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/core/network/api_client.dart';
import 'package:mobilipro/features/admin/presentation/widgets/admin_period_selector.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_search_page.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_seen_tracker.dart';
import 'registration_stats_page.dart';
import 'partner_stats_page.dart';
import 'bookings_stats_page.dart';
import 'trips_list_page.dart';
import 'tickets_list_page.dart';
import 'covoiturage_stats_page.dart';
import 'login_stats_page.dart';
import 'admin_refunds_page.dart';
import 'admin_coupons_page.dart';
import 'admin_claims_page.dart';
import 'admin_transactions_page.dart';


String _currentMonthLabel() {
  const mois = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  return mois[DateTime.now().month - 1];
}

final _monthlyTripsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(
    now.year,
    now.month + 1,
    1,
  ).subtract(const Duration(seconds: 1));
  final f = DateFormat('yyyy-MM-dd');
  final res = await ApiClient.instance.dio.get<List<dynamic>>(
    '/admin/stats/trips/list',
    queryParameters: {'fromDate': f.format(from), 'toDate': f.format(to)},
  );
  return (res.data ?? []).length;
});

final _monthlyRevenueProvider = FutureProvider.autoDispose<double>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(
    now.year,
    now.month + 1,
    1,
  ).subtract(const Duration(seconds: 1));
  final f = DateFormat('yyyy-MM-dd');
  final res = await ApiClient.instance.dio.get<List<dynamic>>(
    '/admin/stats/bookings/list',
    queryParameters: {'fromDate': f.format(from), 'toDate': f.format(to)},
  );
  final bookings = res.data ?? [];
  double total = 0;
  for (final b in bookings) {
    final map = b as Map<String, dynamic>;
    total +=
        (map['totalPrice'] as num?)?.toDouble() ??
        (map['amount'] as num?)?.toDouble() ??
        0;
  }
  return total;
});


final _monthlyBookingsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(
    now.year,
    now.month + 1,
    1,
  ).subtract(const Duration(seconds: 1));
  final f = DateFormat('yyyy-MM-dd');
  final res = await ApiClient.instance.dio.get<List<dynamic>>(
    '/admin/stats/bookings/list',
    queryParameters: {'fromDate': f.format(from), 'toDate': f.format(to)},
  );
  return (res.data ?? []).length;
});

final _monthlyTicketsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(
    now.year,
    now.month + 1,
    1,
  ).subtract(const Duration(seconds: 1));
  final f = DateFormat('yyyy-MM-dd');
  final res = await ApiClient.instance.dio.get<List<dynamic>>(
    '/admin/stats/tickets/list',
    queryParameters: {'fromDate': f.format(from), 'toDate': f.format(to)},
  );
  return (res.data ?? []).length;
});

/// Total de réclamations jamais créées (pas seulement "en attente") — même
/// convention que les autres compteurs de _cardWithBadge : un total qui ne
/// fait que croître, pour que badge = currentTotal - lastSeen se comporte
/// comme partout ailleurs ("combien de nouvelles depuis ma dernière visite").
final _claimsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>('/admin/claims');
  return (res.data ?? []).length;
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

 Widget _cardWithBadge(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String seenKey,
    required int currentTotal,
    required Widget destination,
    String? subtitle,
  }) {
    final seenAsync = ref.watch(
      adminSeenCountProvider((key: seenKey, currentTotal: currentTotal)),
    );
    final seen = seenAsync.valueOrNull ?? currentTotal;
    final badge = (currentTotal - seen).clamp(0, 999);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
        await AdminSeenTracker.markSeen(seenKey, currentTotal);
        ref.invalidate(
          adminSeenCountProvider((key: seenKey, currentTotal: currentTotal)),
        );
      },
      child: KpiCardWithBadge(
        icon: icon,
        label: label,
        value: value,
        color: color,
        badgeCount: badge,
        subtitle: subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Dashboard Admin',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSearchPage()),
            ),
          ),
         IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(adminStatsProvider);
              ref.invalidate(covoiturageStatsProvider(kPeriodMonth));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          ref.invalidate(covoiturageStatsProvider(kPeriodMonth));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AdminSectionTitle(title: 'Vue globale'),
            const SizedBox(height: 10),
            statsAsync.when(
              loading: () => const AdminLoadingCard(),
              error: (e, _) => AdminErrorCard(message: '$e'),
              data: (stats) => Column(
                children: [
                Consumer(
                    builder: (context, ref, _) {
                      final revenueAsync = ref.watch(_monthlyRevenueProvider);
                      return RevenueCard(
                        revenue: revenueAsync.valueOrNull ?? 0,
                        subtitle: _currentMonthLabel(),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _cardWithBadge(
                          context,
                          ref,
                          icon: Icons.people_rounded,
                          label: 'Utilisateurs',
                          value: '${stats.totalUsers}',
                          color: AppColors.mobiliBlue,
                          seenKey: 'users_total_v3',
                          currentTotal: stats.totalUsers,
                          destination: const RegistrationStatsDetailPage(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _cardWithBadge(
                          context,
                          ref,
                          icon: Icons.business_rounded,
                          label: 'Partenaires',
                          value: '${stats.totalPartners}',
                          color: AppColors.proGold,
                          seenKey: 'partners_total_v3',
                          currentTotal: stats.totalPartners,
                          destination: const PartnerStatsDetailPage(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final tripsCountAsync = ref.watch(
                              _monthlyTripsCountProvider,
                            );
                            final tripsCount = tripsCountAsync.valueOrNull ?? 0;
                            return _cardWithBadge(
                              context,
                              ref,
                              icon: Icons.directions_bus_rounded,
                              label: 'Trajets',
                              value: '$tripsCount',
                              color: AppColors.stationGreen,
                              seenKey: 'trips_total_v3',
                              currentTotal: tripsCount,
                              subtitle: _currentMonthLabel(),
                              destination: const TripsListDetailPage(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final bookingsCountAsync = ref.watch(
                              _monthlyBookingsCountProvider,
                            );
                            final bookingsCount =
                                bookingsCountAsync.valueOrNull ?? 0;
                            return _cardWithBadge(
                              context,
                              ref,
                              icon: Icons.bookmark_rounded,
                              label: 'Réservations',
                              value: '$bookingsCount',
                              color: AppColors.warning,
                              seenKey: 'bookings_total_v3',
                              currentTotal: bookingsCount,
                              subtitle: _currentMonthLabel(),
                              destination: const TripStatsDetailPage(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final ticketsCountAsync = ref.watch(
                              _monthlyTicketsCountProvider,
                            );
                            final ticketsCount =
                                ticketsCountAsync.valueOrNull ?? 0;
                            return _cardWithBadge(
                              context,
                              ref,
                              icon: Icons.confirmation_number_rounded,
                              label: 'Tickets vendus',
                              value: '$ticketsCount',
                              color: AppColors.mobiliBlue,
                              seenKey: 'tickets_total_v3',
                              currentTotal: ticketsCount,
                              subtitle: _currentMonthLabel(),
                              destination: const TicketStatsDetailPage(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final covoiturageAsync = ref.watch(
                              covoiturageStatsProvider(kPeriodMonth),
                            );
                            return covoiturageAsync.when(
                              loading: () => const KpiCard(
                                icon: Icons.directions_car_rounded,
                                label: 'Covoiturage',
                                value: '…',
                                color: AppColors.warning,
                              ),
                              error: (e, _) => const KpiCard(
                                icon: Icons.directions_car_rounded,
                                label: 'Covoiturage',
                                value: '—',
                                color: AppColors.warning,
                              ),
                              data: (covStats) => _cardWithBadge(
                                context,
                                ref,
                                icon: Icons.directions_car_rounded,
                                label: 'Covoiturage',
                                value: '${covStats.totalDrivers}',
                                color: AppColors.warning,
                                seenKey: 'covoiturage_total_v3',
                                currentTotal: covStats.totalDrivers,
                                destination: const CovoiturageStatsDetailPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginStatsDetailPage(),
                            ),
                          ),
                          child: const KpiCard(
                            icon: Icons.login_rounded,
                            label: 'Connexions',
                            value: 'Voir',
                            color: AppColors.gray500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AdminSectionTitle(title: 'Gestion'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminRefundsPage(),
                            ),
                          ),
                          child: const KpiCard(
                            icon: Icons.assignment_return_rounded,
                            label: 'Annulations / Remb.',
                            value: 'Gérer',
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminCouponsPage(),
                            ),
                          ),
                          child: const KpiCard(
                            icon: Icons.local_offer_rounded,
                            label: 'Coupons',
                            value: 'Gérer',
                            color: AppColors.proGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final claimsCountAsync = ref.watch(_claimsCountProvider);
                      final claimsCount = claimsCountAsync.valueOrNull ?? 0;
                      return _cardWithBadge(
                        context,
                        ref,
                        icon: Icons.report_problem_rounded,
                        label: 'Réclamations',
                        value: '$claimsCount',
                        color: AppColors.mobiliBlue,
                        seenKey: 'claims_total_v1',
                        currentTotal: claimsCount,
                        destination: const AdminClaimsPage(),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminTransactionsPage(),
                      ),
                    ),
                    child: const KpiCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'Transactions',
                      value: 'Voir',
                      color: AppColors.mobiliBlueDeep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
