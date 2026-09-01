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

/// Bornes calendaires du mois en cours (1er → dernier jour), à passer en tant que
/// AdminStatsPeriod "custom" (fromDate/toDate explicites) aux providers déjà partagés avec les
/// pages Tickets/Trajets/Transactions admin — jamais un simple `kPeriodMonth` (fenêtre glissante
/// de 30 jours), pour que "Ce mois-ci" corresponde exactement au mois calendaire affiché.
AdminStatsPeriod _currentCalendarMonthPeriod() {
  final now = DateTime.now();
  return (
    days: 0,
    fromDate: DateTime(now.year, now.month, 1),
    toDate: DateTime(now.year, now.month + 1, 0),
  );
}

/// Vente brute (totalPrice) du mois par canal — même source que la page Transactions admin
/// (déjà filtrée CONFIRMED/OFFLINE_SALE et sur la date du voyage côté backend), jamais un
/// recalcul depuis /admin/stats/bookings/list qui inclut aussi PENDING/CANCELLED/etc.
final _monthlyRevenueProvider =
    FutureProvider.autoDispose<({double total, double online, double offline})>((ref) async {
      final transactions = await ref.watch(
        transactionListProvider((period: _currentCalendarMonthPeriod(), search: '')).future,
      );
      final online = transactions
          .where((t) => t.status.toUpperCase() == 'CONFIRMED')
          .fold<double>(0, (sum, t) => sum + t.totalPrice);
      final offline = transactions
          .where((t) => t.status.toUpperCase() == 'OFFLINE_SALE')
          .fold<double>(0, (sum, t) => sum + t.totalPrice);
      return (total: online + offline, online: online, offline: offline);
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

/// Tickets vendus du mois, répartis par canal (Via Mobili / Au guichet) — via bookingStatus
/// (statut de la réservation d'origine), distinct du statut du ticket lui-même.
final _monthlyTicketsProvider = FutureProvider.autoDispose<
    ({int total, int online, int offline})>((ref) async {
  final tickets = await ref.watch(
    ticketListProvider((period: _currentCalendarMonthPeriod(), search: '')).future,
  );
  final active = tickets.where((t) => t.status.toUpperCase() != 'ANNULÉ');
  final online = active.where((t) => t.bookingStatus == 'CONFIRMED').length;
  final offline = active.where((t) => t.bookingStatus == 'OFFLINE_SALE').length;
  return (total: online + offline, online: online, offline: offline);
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AdminSectionTitle(title: '📊 Depuis toujours'),
                  const SizedBox(height: 10),
                  _AllTimeRevenueCard(stats: stats),
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
                        child: KpiCard(
                          icon: Icons.directions_bus_rounded,
                          label: 'Trajets (plateforme)',
                          value: '${stats.totalTrips}',
                          color: AppColors.stationGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Tickets vendus (actifs)',
                          value: '${stats.totalTickets}',
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AdminSectionTitle(title: '📅 Ce mois-ci — ${_currentMonthLabel()}'),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final revenueAsync = ref.watch(_monthlyRevenueProvider);
                      final revenue = revenueAsync.valueOrNull ??
                          (total: 0.0, online: 0.0, offline: 0.0);
                      final ticketsAsync = ref.watch(_monthlyTicketsProvider);
                      final tickets = ticketsAsync.valueOrNull ?? (total: 0, online: 0, offline: 0);
                      return _MonthRevenueCard(revenue: revenue, tickets: tickets);
                    },
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
                            final ticketsAsync = ref.watch(_monthlyTicketsProvider);
                            final ticketsCount = ticketsAsync.valueOrNull?.total ?? 0;
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

/// Carte revenus "Depuis toujours" (plateforme) — répartition Via Mobili / Au guichet. Pas de
/// nombre de tickets par canal all-time ici : AdminStatsResponse (backend) ne l'expose que pour
/// le mois en cours (voir _monthlyTicketsProvider), jamais en cumul depuis toujours à ce jour.
class _AllTimeRevenueCard extends StatelessWidget {
  const _AllTimeRevenueCard({required this.stats});
  final AdminStats stats;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenus plateforme — depuis toujours',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(stats.totalRevenue)} FCFA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RevenueChip(
                icon: Icons.wifi_rounded,
                label: 'Via Mobili',
                amount: stats.revenueOnline,
                color: AppColors.stationGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RevenueChip(
                icon: Icons.point_of_sale_rounded,
                label: 'Au guichet',
                amount: stats.revenueOffline,
                color: AppColors.mobiliYellow,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Carte revenus "Ce mois-ci" — répartition Via Mobili / Au guichet, avec nombre de tickets
/// vendus par canal (disponible côté mois, contrairement au bloc all-time ci-dessus).
class _MonthRevenueCard extends StatelessWidget {
  const _MonthRevenueCard({required this.revenue, required this.tickets});
  final ({double total, double online, double offline}) revenue;
  final ({int total, int online, int offline}) tickets;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenus plateforme — ${_currentMonthLabel()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(revenue.total)} FCFA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RevenueChip(
                icon: Icons.wifi_rounded,
                label: 'Via Mobili',
                amount: revenue.online,
                ticketCount: tickets.online,
                color: AppColors.stationGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RevenueChip(
                icon: Icons.point_of_sale_rounded,
                label: 'Au guichet',
                amount: revenue.offline,
                ticketCount: tickets.offline,
                color: AppColors.mobiliYellow,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RevenueChip extends StatelessWidget {
  const _RevenueChip({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
    this.ticketCount,
  });
  final IconData icon;
  final String label;
  final double amount;
  final Color color;
  /// Nombre de tickets vendus sur ce canal — affiché en plus du montant si fourni.
  final int? ticketCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(
                '${NumberFormat('#,###').format(amount)} F',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontSize: 13,
                ),
              ),
              if (ticketCount != null)
                Text(
                  '$ticketCount ticket${ticketCount! > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.85)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
