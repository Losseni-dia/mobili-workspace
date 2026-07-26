import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/features/chauffeurs/widgets/chauffeur_dashboard_widgets.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/chauffeur_dashboard_models.dart';
import 'chauffeur_history_page.dart';
import 'trip_detail_chauffeur_page.dart';

class DashboardChauffeurPage extends ConsumerWidget {
  const DashboardChauffeurPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(chauffeurOverviewProvider);
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.gray50,
      floatingActionButton: profile?.isCovoiturageDriver == true
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push<bool>(
                  '/covoiturage/trips/new',
                );
                if (created == true) ref.invalidate(chauffeurOverviewProvider);
              },
              backgroundColor: AppColors.mobiliYellow,
              foregroundColor: AppColors.mobiliBlueDeep,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Publier un trajet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async => ref.invalidate(chauffeurOverviewProvider),
        child: CustomScrollView(
          slivers: [
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
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
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
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              color: AppColors.mobiliBlueDeep,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bonjour, ${profile?.firstname ?? 'Chauffeur'}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'EEEE dd MMMM yyyy',
                                    'fr_FR',
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
                          GestureDetector(
                            onTap: () => context.go('/chauffeur/scanner'),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: AppColors.white,
                                size: 22,
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
            overviewAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.mobiliBlue),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                          e.toString(),
                          style: const TextStyle(color: AppColors.gray500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(chauffeurOverviewProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mobiliBlue,
                          ),
                          child: const Text(
                            'Réessayer',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (overview) => SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildNextTrip(context, overview),
                    const SizedBox(height: 20),
                    _buildUpcomingTrips(context, overview),
                    const SizedBox(height: 20),
                    if (profile?.isCovoiturageDriver == true) ...[
                      _buildCovoiturageStats(context, ref),
                      const SizedBox(height: 20),
                    ],
                    _buildHistoryLink(context, overview.history),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, ChauffeurTripItem trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailChauffeurPage(trip: trip)),
    );
  }

  Widget _buildNextTrip(BuildContext context, ChauffeurOverview overview) {
    final next = overview.upcoming.isNotEmpty ? overview.upcoming.first : null;
    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_busy_rounded, color: AppColors.gray300, size: 32),
            SizedBox(width: 12),
            Text(
              'Aucun trajet à venir',
              style: TextStyle(color: AppColors.gray400, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          icon: Icons.navigate_next_rounded,
          label: 'Prochain trajet',
        ),
        const SizedBox(height: 10),
        NextTripCard(trip: next, onDetail: () => _openDetail(context, next)),
      ],
    );
  }

  Widget _buildUpcomingTrips(BuildContext context, ChauffeurOverview overview) {
    final relevant = overview.upcoming
        .where((t) => t.isInProgress || t.isToday || t.isTomorrow)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SectionTitle(
              icon: Icons.today_rounded,
              label: 'Aujourd\'hui & demain',
            ),
            const Spacer(),
            if (relevant.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.mobiliBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${relevant.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (relevant.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray200),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.stationGreen,
                  size: 20,
                ),
                SizedBox(width: 10),
                Text(
                  'Aucun trajet aujourd\'hui ou demain',
                  style: TextStyle(color: AppColors.gray500, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...relevant.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TripCard(trip: t, onDetail: () => _openDetail(context, t)),
            ),
          ),
      ],
    );
  }

  Widget _buildCovoiturageStats(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(covoiturageDashboardStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Réservations indisponibles : $e',
                style: const TextStyle(color: AppColors.gray500, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.dashboard_rounded,
            label: 'Mon activité covoiturage',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatCard(
                icon: Icons.directions_car_filled_rounded,
                label: 'Trajets publiés',
                value: '${stats.activeTripsCount}',
                color: AppColors.mobiliBlue,
              ),
              const SizedBox(width: 12),
              StatCard(
                icon: Icons.bookmark_rounded,
                label: 'Réservations',
                value: '${stats.totalBookingsCount}',
                color: AppColors.stationGreen,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: AppColors.mobiliYellow,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
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
                    Text(
                      '${NumberFormat('#,###').format(stats.totalRevenue)} FCFA',
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
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Réservations récentes',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.mobiliBlueDeep,
                  fontSize: 14,
                ),
              ),
              Text(
                '${stats.recentBookings.length} au total',
                style: const TextStyle(fontSize: 12, color: AppColors.gray400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (stats.recentBookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray200),
              ),
              child: const Center(
                child: Text(
                  'Aucune réservation pour le moment',
                  style: TextStyle(color: AppColors.gray400, fontSize: 13),
                ),
              ),
            )
          else
            ...stats.recentBookings
                .take(5)
                .map((b) => RecentBookingCard(booking: b)),
        ],
      ),
    );
  }

  Widget _buildHistoryLink(
    BuildContext context,
    List<ChauffeurTripItem> history,
  ) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChauffeurHistoryPage(history: history),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              color: AppColors.mobiliBlue,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Historique des trajets',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.mobiliBlueDeep,
                  fontSize: 14,
                ),
              ),
            ),
            if (history.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${history.length}',
                  style: const TextStyle(
                    color: AppColors.gray500,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }
}
