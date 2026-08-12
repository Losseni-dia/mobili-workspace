import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/features/partner/presentation/pages/partner_stations_list_page.dart';
import 'package:mobilipro/features/partner/presentation/widgets/partner_period_selector.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/partner_shared_providers.dart';
import 'partner_bookings_list_page.dart';
import 'partner_transactions_page.dart';
import 'partner_tickets_list_page.dart';
import 'partner_trips_list_page.dart';
import 'package:mobilipro/features/admin/presentation/widgets/admin_seen_tracker.dart';
import 'package:mobilipro/features/admin/presentation/widgets/admin_common_widgets.dart'
    show KpiCardWithBadge;

// ─────────────────────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────────────────────

class PartnerDashboardStats {
  const PartnerDashboardStats({
    required this.activeTripsCount,
    required this.totalBookingsCount,
    required this.totalRevenue,
    required this.revenueOnline,
    required this.revenueOffline,
    required this.recentBookings,
  });

  final int activeTripsCount;
  final int totalBookingsCount;
  final double totalRevenue;
  final double revenueOnline;
  final double revenueOffline;
  final List<PartnerRecentBooking> recentBookings;

  factory PartnerDashboardStats.fromJson(Map<String, dynamic> json) =>
      PartnerDashboardStats(
        activeTripsCount: (json['activeTripsCount'] as num?)?.toInt() ?? 0,
        totalBookingsCount: (json['totalBookingsCount'] as num?)?.toInt() ?? 0,
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        revenueOnline: (json['revenueOnline'] as num?)?.toDouble() ?? 0.0,
        revenueOffline: (json['revenueOffline'] as num?)?.toDouble() ?? 0.0,
        recentBookings: (json['recentBookings'] as List<dynamic>? ?? [])
            .map(
              (e) => PartnerRecentBooking.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

class PartnerRecentBooking {
  const PartnerRecentBooking({
    required this.id,
    required this.customerName,
    required this.tripRoute,
    required this.date,
    required this.amount,
    required this.status,
    required this.passengerNames,
    required this.seatNumbers,
  });

  final int id;
  final String customerName;
  final String tripRoute;
  final DateTime date;
  final double amount;
  final String status;
  final List<String> passengerNames;
  final List<String> seatNumbers;

  String get displayName =>
      passengerNames.isNotEmpty ? passengerNames.join(', ') : customerName;
  String get displayInitial {
    final n = passengerNames.isNotEmpty ? passengerNames.first : customerName;
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  String get formattedAmount => '${NumberFormat('#,###').format(amount)} FCFA';

  factory PartnerRecentBooking.fromJson(Map<String, dynamic> json) =>
      PartnerRecentBooking(
        id: json['id'] as int,
        customerName: json['customerName'] as String? ?? '',
        tripRoute: json['tripRoute'] as String? ?? '',
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? '',
        passengerNames: (json['passengerNames'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        seatNumbers: (json['seatNumbers'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _partnerDashboardProvider =
    FutureProvider.autoDispose<PartnerDashboardStats>((ref) async {
      final dio = ApiClient.instance.dio;
      final response = await dio.get<Map<String, dynamic>>(
        '/partenaire/dashboard/stats',
      );
      return PartnerDashboardStats.fromJson(response.data!);
    });

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

final _monthlyActiveTripsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(
    now.year,
    now.month + 1,
    1,
  ).subtract(const Duration(seconds: 1));
  final f = DateFormat('yyyy-MM-dd');
  final response = await dio.get<List<dynamic>>(
    '/trips/my-trips/range',
    queryParameters: {'fromDate': f.format(from), 'toDate': f.format(to)},
  );
  final trips = response.data ?? [];
  return trips
      .where((t) => (t as Map<String, dynamic>)['status'] != 'ANNULÉ')
      .length;
});

final _monthlyBookingsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(
    now.year,
    now.month + 1,
    1,
  ).subtract(const Duration(seconds: 1));
  final f = DateFormat('yyyy-MM-dd');
  final response = await dio.get<List<dynamic>>(
    '/bookings/partner/my-bookings/range',
    queryParameters: {'fromDate': f.format(from), 'toDate': f.format(to)},
  );
  final bookings = response.data ?? [];
  return bookings.where((b) {
    final status = (b as Map<String, dynamic>)['status'] as String?;
    return status == 'CONFIRMED' || status == 'OFFLINE_SALE';
  }).length;
});

final _monthlyRevenueProvider =
    FutureProvider.autoDispose<({double total, double online, double offline})>(
      (ref) async {
        final dio = ApiClient.instance.dio;
        final now = DateTime.now();
        final from = DateTime(now.year, now.month, 1);
        final to = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(const Duration(seconds: 1));
        final f = DateFormat('yyyy-MM-dd');
        final response = await dio.get<List<dynamic>>(
          '/bookings/partner/my-bookings/range',
          queryParameters: {'fromDate': f.format(from), 'toDate': f.format(to)},
        );
        final bookings = response.data ?? [];
        double online = 0;
        double offline = 0;
        for (final b in bookings) {
          final map = b as Map<String, dynamic>;
          final status = map['status'] as String?;
          final amount =
              (map['amount'] as num?)?.toDouble() ??
              (map['totalPrice'] as num?)?.toDouble() ??
              0;
          if (status == 'CONFIRMED') online += amount;
          if (status == 'OFFLINE_SALE') offline += amount;
        }
        return (total: online + offline, online: online, offline: offline);
      },
    );

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPartnerPage extends ConsumerWidget {
  const DashboardPartnerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_partnerDashboardProvider);
    final stationsAsync = ref.watch(partnerStationsProvider);
    final profile = ref.watch(authProvider).valueOrNull?.profile;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/partner/dashboard/trips/create'),
        backgroundColor: AppColors.mobiliBlue,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(
          'Nouveau trajet',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async {
          ref.invalidate(_partnerDashboardProvider);
          ref.invalidate(partnerStationsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 150,
              pinned: true,
              backgroundColor: AppColors.mobiliBlue,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.proGold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'P',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.mobiliBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bonjour, ${profile?.firstname ?? ''}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(DateTime.now()),
                                  style: TextStyle(
                                    color: AppColors.white.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.proGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.proGold.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'Dirigeant',
                              style: TextStyle(
                                color: AppColors.proGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI — cartes cliquables uniquement
                    dashAsync.when(
                      loading: () => const SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mobiliBlue,
                          ),
                        ),
                      ),
                      error: (e, _) => _ErrorBox(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(_partnerDashboardProvider),
                      ),
                      data: (stats) => Column(
                        children: [
                          Consumer(
                            builder: (context, ref, _) {
                              final revenueAsync = ref.watch(
                                _monthlyRevenueProvider,
                              );
                              final revenue =
                                  revenueAsync.valueOrNull ??
                                  (total: 0.0, online: 0.0, offline: 0.0);
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0A1F6E),
                                      AppColors.mobiliBlueDeep,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.payments_rounded,
                                            color: AppColors.mobiliYellow,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Revenus — ${_currentMonthLabel()}',
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${NumberFormat('#,###').format(revenue.total)} FCFA',
                                              style: const TextStyle(
                                                color: AppColors.mobiliYellow,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(
                                      color: Colors.white12,
                                      height: 1,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _RevenueChip(
                                            icon: Icons.wifi_rounded,
                                            label: 'En ligne',
                                            amount: revenue.online,
                                            color: AppColors.stationGreen,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _RevenueChip(
                                            icon: Icons.point_of_sale_rounded,
                                            label: 'Physique',
                                            amount: revenue.offline,
                                            color: AppColors.mobiliYellow,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final tripsCountAsync = ref.watch(
                                      _monthlyActiveTripsCountProvider,
                                    );
                                    final tripsCount =
                                        tripsCountAsync.valueOrNull ?? 0;
                                    return _PartnerBadgeCard(
                                      ref: ref,
                                      icon: Icons.directions_bus_rounded,
                                      label: 'Trajets actifs',
                                      value: '$tripsCount',
                                      color: AppColors.mobiliBlue,
                                      seenKey: 'partner_trips_total',
                                      currentTotal: tripsCount,
                                      subtitle: _currentMonthLabel(),
                                      destination: const PartnerTripsListPage(),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final bookingsCountAsync = ref.watch(
                                      _monthlyBookingsCountProvider,
                                    );
                                    final bookingsCount =
                                        bookingsCountAsync.valueOrNull ?? 0;
                                    return _PartnerBadgeCard(
                                      ref: ref,
                                      icon: Icons.bookmark_rounded,
                                      label: 'Réservations',
                                      value: '$bookingsCount',
                                      color: AppColors.stationGreen,
                                      seenKey: 'partner_bookings_total',
                                      currentTotal: bookingsCount,
                                      subtitle: _currentMonthLabel(),
                                      destination:
                                          const PartnerBookingsListPage(),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Consumer(
                            builder: (context, ref, _) {
                              final ticketsAsync = ref.watch(
                                partnerTicketsRangeProvider((
                                  period: PartnerPeriod.month,
                                  stationId: null,
                                  search: '',
                                )),
                              );
                              final total = ticketsAsync.valueOrNull?.length;
                              if (total == null) {
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PartnerTicketsListPage(),
                                    ),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.gray200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.proGold.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.confirmation_number_rounded,
                                            color: AppColors.proGold,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Tickets vendus',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.mobiliBlueDeep,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.gray300,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return _PartnerBadgeCard(
                                ref: ref,
                                icon: Icons.confirmation_number_rounded,
                                label: 'Tickets vendus',
                                value: '$total',
                                color: AppColors.proGold,
                                seenKey: 'partner_tickets_total',
                                currentTotal: total,
                                subtitle: _currentMonthLabel(),
                                destination: const PartnerTicketsListPage(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PartnerStationsListPage(),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gray200),
                          boxShadow: AppColors.shadowSm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.stationGreen.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.store_rounded,
                                color: AppColors.stationGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mes gares',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mobiliBlueDeep,
                                    ),
                                  ),
                                  stationsAsync.whenOrNull(
                                        data: (s) => Text(
                                          '${s.length} gare(s)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.gray400,
                                          ),
                                        ),
                                      ) ??
                                      const SizedBox.shrink(),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.gray300,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PartnerTransactionsPage(),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gray200),
                          boxShadow: AppColors.shadowSm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.mobiliBlueDeep.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.mobiliBlueDeep,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Transactions',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mobiliBlueDeep,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.gray300,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gray200),
      boxShadow: AppColors.shadowSm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.gray500,
            fontWeight: FontWeight.w500,
          ),
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
  });
  final IconData icon;
  final String label;
  final double amount;
  final Color color;

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
            ],
          ),
        ),
      ],
    ),
  );
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.station, required this.onTap});
  final StationItem station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: station.active
              ? AppColors.stationGreen.withValues(alpha: 0.3)
              : AppColors.gray200,
        ),
        boxShadow: AppColors.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: station.active
                  ? AppColors.stationGreen.withValues(alpha: 0.1)
                  : AppColors.gray100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.store_rounded,
              size: 24,
              color: station.active
                  ? AppColors.stationGreen
                  : AppColors.gray400,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                Text(
                  station.city,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 12,
                      color: AppColors.gray400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      station.responsibleName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray400,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.directions_car_rounded,
                      size: 12,
                      color: AppColors.gray400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${station.chauffeurs.length} chauffeur(s)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: station.active
                      ? AppColors.stationGreen
                      : AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.gray300),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.dangerSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    ),
  );
}

class _PartnerBadgeCard extends StatelessWidget {
  const _PartnerBadgeCard({
    required this.ref,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.seenKey,
    required this.currentTotal,
    required this.destination,
    this.subtitle,
  });
  final WidgetRef ref;
  final IconData icon;
  final String label, value, seenKey;
  final Color color;
  final int currentTotal;
  final Widget destination;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
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
}
