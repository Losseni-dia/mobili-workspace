import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/features/auth/providers/auth_provider.dart';
import 'package:mobilipro/features/stations/presentation/pages/bookings_gare_page.dart';
import 'package:mobilipro/features/stations/presentation/pages/gare_transactions_page.dart';
import 'package:mobilipro/features/stations/presentation/pages/tickets_gare_page.dart';
import 'package:mobilipro/features/trips/presentation/pages/trips_gare_page.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

import 'package:mobilipro/features/admin/presentation/widgets/admin_seen_tracker.dart';
import 'package:mobilipro/features/admin/presentation/widgets/admin_common_widgets.dart'
    show KpiCardWithBadge;
import 'package:mobilipro/features/partner/presentation/widgets/partner_period_selector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────────────────────

class DashboardStats {
  const DashboardStats({
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
  final List<RecentBooking> recentBookings;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    activeTripsCount: (json['activeTripsCount'] as num?)?.toInt() ?? 0,
    totalBookingsCount: (json['totalBookingsCount'] as num?)?.toInt() ?? 0,
    totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
    revenueOnline: (json['revenueOnline'] as num?)?.toDouble() ?? 0.0,
    revenueOffline: (json['revenueOffline'] as num?)?.toDouble() ?? 0.0,
    recentBookings: (json['recentBookings'] as List<dynamic>? ?? [])
        .map((e) => RecentBooking.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class RecentBooking {
  const RecentBooking({
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
    final name = passengerNames.isNotEmpty
        ? passengerNames.first
        : customerName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get formattedAmount => '${NumberFormat('#,###').format(amount)} FCFA';

  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(date);

  factory RecentBooking.fromJson(Map<String, dynamic> json) => RecentBooking(
    id: json['id'] as int,
    customerName: json['customerName'] as String? ?? '',
    tripRoute: json['tripRoute'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
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
// Provider
// ─────────────────────────────────────────────────────────────────────────────

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

final _dashboardProvider = FutureProvider.autoDispose<DashboardStats>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<Map<String, dynamic>>(
    '/partenaire/dashboard/stats',
  );
  return DashboardStats.fromJson(response.data!);
});

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
  final trips = (response.data ?? [])
      .map((e) => TripItem.fromJson(e as Map<String, dynamic>))
      .toList();
  return trips.where((t) => t.status != 'ANNULÉ').length;
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
          // Vente brute — JAMAIS amount/totalPrice seuls, qui incluent le forfait client
          // (jamais reversé à la compagnie). Même formule que PartnerBookingItem.grossAmount,
          // pour que ce chiffre reste aligné avec la page Réservations de la gare.
          final ticketsTotalAmount =
              (map['ticketsTotalAmount'] as num?)?.toDouble();
          final luggageFee = (map['luggageFee'] as num?)?.toDouble() ?? 0;
          final amount = ticketsTotalAmount != null
              ? ticketsTotalAmount + luggageFee
              : (map['amount'] as num?)?.toDouble() ??
                  (map['totalPrice'] as num?)?.toDouble() ??
                  0;
          if (status == 'CONFIRMED') online += amount;
          if (status == 'OFFLINE_SALE') offline += amount;
        }
        return (total: online + offline, online: online, offline: offline);
      },
    );

final _recentBookingsVisibleCountProvider = StateProvider.autoDispose<int>(
  (ref) => 10,
);
// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class DashboardGarePage extends ConsumerWidget {
  const DashboardGarePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_dashboardProvider);
    final profile = ref.watch(authProvider).valueOrNull?.profile;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/gare/trips/create'),
        backgroundColor: AppColors.mobiliBlue,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(
          'Nouveau trajet',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async => ref.invalidate(_dashboardProvider),
        child: CustomScrollView(
          slivers: [
            // AppBar
            SliverAppBar(
              expandedHeight: 140,
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
                              color: AppColors.mobiliYellow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'M',
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
                              'Gare',
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
              child: dashAsync.when(
                loading: () => const SizedBox(
                  height: 400,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.mobiliBlue,
                    ),
                  ),
                ),
                error: (e, _) => SizedBox(
                  height: 400,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Erreur : $e',
                          style: const TextStyle(color: AppColors.gray500),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(_dashboardProvider),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (stats) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Revenus total
                      // Revenus total (mois en cours)
                      Consumer(
                        builder: (context, ref, _) {
                          final revenueAsync = ref.watch(
                            _monthlyRevenueProvider,
                          );
                          final revenue =
                              revenueAsync.valueOrNull ??
                              (total: 0.0, online: 0.0, offline: 0.0);
                          return InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BookingsGarePage(),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
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
                                          const Text(
                                            'Revenus du mois',
                                            style: TextStyle(
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
                                  // Deux totaux
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RevenueChip(
                                          icon: Icons.wifi_rounded,
                                          label: 'Via Mobili',
                                          amount: revenue.online,
                                          color: AppColors.stationGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _RevenueChip(
                                          icon: Icons.point_of_sale_rounded,
                                          label: 'Au guichet',
                                          amount: revenue.offline,
                                          color: AppColors.mobiliYellow,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Stats trajets + réservations (données du mois en cours)
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
                                return _GareBadgeCard(
                                  ref: ref,
                                  icon: Icons.directions_bus_rounded,
                                  label: 'Trajets actifs',
                                  value: '$tripsCount',
                                  color: AppColors.mobiliBlue,
                                  seenKey: 'gare_trips_total',
                                  currentTotal: tripsCount,
                                  subtitle: _currentMonthLabel(),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TripsGarePage(),
                                    ),
                                  ),
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
                                return _GareBadgeCard(
                                  ref: ref,
                                  icon: Icons.bookmark_rounded,
                                  label: 'Réservations',
                                  value: '$bookingsCount',
                                  color: AppColors.stationGreen,
                                  seenKey: 'gare_bookings_total',
                                  currentTotal: bookingsCount,
                                  subtitle: _currentMonthLabel(),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const BookingsGarePage(),
                                    ),
                                  ),
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
                            gareTicketsRangeProvider((
                              period: PartnerPeriod.month,
                              search: '',
                            )),
                          );
                          final total = ticketsAsync.valueOrNull?.length;
                          if (total == null) {
                            return InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TicketsGarePage(),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.gray200),
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
                                        borderRadius: BorderRadius.circular(10),
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
                          return _GareBadgeCard(
                            ref: ref,
                            icon: Icons.confirmation_number_rounded,
                            label: 'Tickets vendus',
                            value: '$total',
                            color: AppColors.proGold,
                            seenKey: 'gare_tickets_total',
                            currentTotal: total,
                            subtitle: _currentMonthLabel(),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TicketsGarePage(),
                              ),
                            ),
                          );
                        },
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GareTransactionsPage(),
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Réservations récentes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mobiliBlueDeep,
                            ),
                          ),
                          Text(
                            '${stats.recentBookings.length} au total',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                      if (stats.recentBookings.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: const Center(
                            child: Text(
                              'Aucune réservation récente',
                              style: TextStyle(color: AppColors.gray400),
                            ),
                          ),
                        )
                      else
                        Consumer(
                          builder: (context, ref, _) {
                            final visibleCount = ref.watch(
                              _recentBookingsVisibleCountProvider,
                            );
                            final visible = stats.recentBookings
                                .take(visibleCount)
                                .toList();
                            final hasMore =
                                stats.recentBookings.length > visibleCount;
                            return Column(
                              children: [
                                ...visible.map((b) => _BookingItem(booking: b)),
                                if (hasMore)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          ref
                                                  .read(
                                                    _recentBookingsVisibleCountProvider
                                                        .notifier,
                                                  )
                                                  .state +=
                                              10,
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        'Voir plus (${stats.recentBookings.length - visibleCount} restant(s))',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.mobiliBlue,
                                        side: const BorderSide(
                                          color: AppColors.mobiliBlue,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
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
    ),
  );
}

class _BookingItem extends StatelessWidget {
  const _BookingItem({required this.booking});
  final RecentBooking booking;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(booking.status);
    final isOffline = booking.status == 'OFFLINE_SALE';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOffline
                  ? AppColors.mobiliBlueFog
                  : const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                booking.displayInitial,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isOffline
                      ? AppColors.mobiliBlue
                      : AppColors.stationGreen,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.mobiliBlueDeep,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  booking.tripRoute,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray500,
                  ),
                ),
                if (booking.seatNumbers.isNotEmpty)
                  Text(
                    'Sièges : ${booking.seatNumbers.join(', ')}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mobiliBlue,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (booking.amount > 0)
                Text(
                  booking.formattedAmount,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusConfig.$1,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(booking.status),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusConfig.$2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Via Mobili';
      case 'PENDING':
        return 'En attente';
      case 'CANCELLED':
        return 'Annulé';
      case 'OFFLINE_SALE':
        return 'Au guichet';
      default:
        return status;
    }
  }

  (Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'PENDING':
        return (AppColors.warningSoft, AppColors.warning);
      case 'CANCELLED':
        return (AppColors.dangerSoft, AppColors.danger);
      case 'OFFLINE_SALE':
        return (AppColors.mobiliBlueFog, AppColors.mobiliBlue);
      default:
        return (AppColors.gray100, AppColors.gray500);
    }
  }
}

class _GareBadgeCard extends StatelessWidget {
  const _GareBadgeCard({
    required this.ref,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.seenKey,
    required this.currentTotal,
    required this.onTap,
    this.subtitle,
  });
  final WidgetRef ref;
  final IconData icon;
  final String label, value, seenKey;
  final Color color;
  final int currentTotal;
  final VoidCallback onTap;
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
        onTap();
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
