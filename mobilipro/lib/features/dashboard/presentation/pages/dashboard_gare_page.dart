import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/features/auth/providers/auth_provider.dart';

import '../../../../../../core/network/api_client.dart';
import '../../../../../../core/theme/app_colors.dart';
// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────

class DashboardStats {
  const DashboardStats({
    required this.activeTripsCount,
    required this.totalBookingsCount,
    required this.totalRevenue,
    required this.recentBookings,
  });

  final int activeTripsCount;
  final int totalBookingsCount;
  final double totalRevenue;
  final List<RecentBooking> recentBookings;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    activeTripsCount: (json['activeTripsCount'] as num?)?.toInt() ?? 0,
    totalBookingsCount: (json['totalBookingsCount'] as num?)?.toInt() ?? 0,
    totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
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
  });

  final int id;
  final String customerName;
  final String tripRoute;
  final DateTime date;
  final double amount;
  final String status;

  factory RecentBooking.fromJson(Map<String, dynamic> json) => RecentBooking(
    id: json['id'] as int,
    customerName: json['customerName'] as String? ?? '',
    tripRoute: json['tripRoute'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] as String? ?? '',
  );

  String get formattedAmount => NumberFormat('#,###').format(amount) + ' FCFA';

  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(date);
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final _dashboardProvider = FutureProvider.autoDispose<DashboardStats>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<Map<String, dynamic>>(
    '/partenaire/dashboard/stats',
  );
  return DashboardStats.fromJson(response.data!);
});

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
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async => ref.invalidate(_dashboardProvider),
        child: CustomScrollView(
          slivers: [
            // ── AppBar ───────────────────────────────────────────
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
                      // ── Stats cards ──────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.directions_bus_rounded,
                              label: 'Trajets actifs',
                              value: '${stats.activeTripsCount}',
                              color: AppColors.mobiliBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.bookmark_rounded,
                              label: 'Réservations',
                              value: '${stats.totalBookingsCount}',
                              color: AppColors.stationGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Revenus total
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.mobiliBlue,
                              AppColors.mobiliBlueDeep,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: AppColors.mobiliYellow,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Revenus totaux',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              Text(
                                  NumberFormat(
                                        '#,###',
                                      ).format(stats.totalRevenue) +
                                      ' FCFA',
                                  style: const TextStyle(
                                    color: AppColors.mobiliYellow,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Réservations récentes ────────────────
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
                        ...stats.recentBookings
                            .take(10)
                            .map((b) => _BookingItem(booking: b))
                            .toList(),

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

class _BookingItem extends StatelessWidget {
  const _BookingItem({required this.booking});
  final RecentBooking booking;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(booking.status);

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
              color: AppColors.mobiliBlueFog,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.mobiliBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  booking.tripRoute,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray500,
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
                  booking.status,
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
