import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/features/chauffeurs/presentation/pages/trip_detail_chauffeur_page.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import 'dashboard_partner_page.dart' show PartnerDashboardStats, PartnerRecentBooking;

// ─────────────────────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────────────────────

class ChauffeurTripItem {
  const ChauffeurTripItem({
    required this.id,
    required this.source,
    required this.departureCity,
    required this.arrivalCity,
    this.boardingPoint,
    required this.departureDateTime,
    required this.status,
    this.partnerName,
    this.stationName,
    this.vehiculePlateNumber,
    this.vehicleType,
  });

  final int id;
  final String source;
  final String departureCity;
  final String arrivalCity;
  final String? boardingPoint;
  final DateTime departureDateTime;
  final String status;
  final String? partnerName;
  final String? stationName;
  final String? vehiculePlateNumber;
  final String? vehicleType;

  String get route => '$departureCity → $arrivalCity';
  String get formattedDate =>
      DateFormat('dd/MM/yyyy HH:mm').format(departureDateTime);
  String get formattedDay =>
      DateFormat('EEEE dd MMM', 'fr_FR').format(departureDateTime);

  bool get isToday {
    final now = DateTime.now();
    return departureDateTime.year == now.year &&
        departureDateTime.month == now.month &&
        departureDateTime.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return departureDateTime.year == tomorrow.year &&
        departureDateTime.month == tomorrow.month &&
        departureDateTime.day == tomorrow.day;
  }

  bool get isInProgress => status == 'EN_COURS';
  bool get isUpcoming =>
      status == 'PROGRAMMÉ' || status == 'PLANIFIE' || status == 'ASSIGNED';
  bool get isCompleted =>
      status == 'TERMINÉ' || status == 'TERMINE' || status == 'COMPLETED';

  factory ChauffeurTripItem.fromJson(Map<String, dynamic> json) =>
      ChauffeurTripItem(
        id: (json['id'] as num).toInt(),
        source: json['source'] as String? ?? 'ASSIGNED',
        departureCity: json['departureCity'] as String? ?? '',
        arrivalCity: json['arrivalCity'] as String? ?? '',
        boardingPoint: json['boardingPoint'] as String?,
        departureDateTime:
            DateTime.tryParse(json['departureDateTime'] as String? ?? '') ??
            DateTime.now(),
        status: json['status'] as String? ?? '',
        partnerName: json['partnerName'] as String?,
        stationName: json['stationName'] as String?,
        vehiculePlateNumber: json['vehiculePlateNumber'] as String?,
        vehicleType: json['vehicleType'] as String?,
      );
}

class ChauffeurOverview {
  const ChauffeurOverview({required this.upcoming, required this.history});
  final List<ChauffeurTripItem> upcoming;
  final List<ChauffeurTripItem> history;

  factory ChauffeurOverview.fromJson(Map<String, dynamic> json) =>
      ChauffeurOverview(
        upcoming: (json['upcoming'] as List<dynamic>? ?? [])
            .map((e) => ChauffeurTripItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => ChauffeurTripItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final chauffeurOverviewProvider = FutureProvider.autoDispose<ChauffeurOverview>(
  (ref) async {
    final dio = ApiClient.instance.dio;
    final res = await dio.get<Map<String, dynamic>>('/trips/chauffeur/mine');
    return ChauffeurOverview.fromJson(res.data!);
  },
);

/// Synthèse "gare/partenaire" pour le conducteur covoiturage : trajets,
/// réservations, revenus — scopée sur SES trajets (jamais le pool entier).
/// N'est watché/affiché que si `profile.isCovoiturageDriver`.
final covoiturageDashboardStatsProvider =
    FutureProvider.autoDispose<PartnerDashboardStats>((ref) async {
  final dio = ApiClient.instance.dio;
  final res = await dio.get<Map<String, dynamic>>('/covoiturage/trips/dashboard/stats');
  return PartnerDashboardStats.fromJson(res.data!);
});

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class DashboardChauffeurPage extends ConsumerWidget {
  const DashboardChauffeurPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(chauffeurOverviewProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      // Réservé aux conducteurs covoiturage (KYC approuvé) : un chauffeur
      // compagnie classique, même avec le rôle CHAUFFEUR, ne crée jamais de
      // trajet — il ne conduit que ce qui lui est assigné par sa gare/société.
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
              label: const Text('Publier un trajet',
                  style: TextStyle(fontWeight: FontWeight.w700)),
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
        const _SectionTitle(
          icon: Icons.navigate_next_rounded,
          label: 'Prochain trajet',
        ),
        const SizedBox(height: 10),
        _NextTripCard(trip: next, onDetail: () => _openDetail(context, next)),
      ],
    );
  }

  Widget _buildUpcomingTrips(BuildContext context, ChauffeurOverview overview) {
    // Aujourd'hui, demain, et tout trajet en cours (même si planifié plus tard) :
    // on ne sature pas l'écran avec les trajets lointains, l'historique reste à
    // portée de main via le lien "Historique".
    final relevant = overview.upcoming
        .where((t) => t.isInProgress || t.isToday || t.isTomorrow)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionTitle(
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
              child: _TripCard(
                trip: t,
                onDetail: () => _openDetail(context, t),
              ),
            ),
          ),
      ],
    );
  }

  /// Synthèse "gare/partenaire" pour le conducteur covoiturage : trajets,
  /// réservations, revenus — jamais affichée pour un chauffeur compagnie.
  Widget _buildCovoiturageStats(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(covoiturageDashboardStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
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
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Réservations indisponibles : $e',
                  style: const TextStyle(color: AppColors.gray500, fontSize: 12)),
            ),
          ],
        ),
      ),
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.dashboard_rounded, label: 'Mon activité covoiturage'),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCard(
                icon: Icons.directions_car_filled_rounded,
                label: 'Trajets publiés',
                value: '${stats.activeTripsCount}',
                color: AppColors.mobiliBlue,
              ),
              const SizedBox(width: 12),
              _StatCard(
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
                  child: const Icon(Icons.payments_rounded, color: AppColors.mobiliYellow, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenus totaux',
                        style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w500)),
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
              const Text('Réservations récentes',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.mobiliBlueDeep, fontSize: 14)),
              Text('${stats.recentBookings.length} au total',
                  style: const TextStyle(fontSize: 12, color: AppColors.gray400)),
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
                child: Text('Aucune réservation pour le moment',
                    style: TextStyle(color: AppColors.gray400, fontSize: 13)),
              ),
            )
          else
            ...stats.recentBookings.take(5).map((b) => _RecentBookingCard(booking: b)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Historique (trajets passés, accessible sur demande)
// ─────────────────────────────────────────────────────────────────────────────

class ChauffeurHistoryPage extends StatelessWidget {
  const ChauffeurHistoryPage({super.key, required this.history});
  final List<ChauffeurTripItem> history;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Historique des trajets',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: AppColors.gray300,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Aucun trajet passé',
                      style: TextStyle(color: AppColors.gray400, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TripCard(
                  trip: history[i],
                  isHistory: true,
                  onDetail: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TripDetailChauffeurPage(trip: history[i]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card prochain trajet (grande)
// ─────────────────────────────────────────────────────────────────────────────

class _NextTripCard extends StatelessWidget {
  const _NextTripCard({required this.trip, required this.onDetail});
  final ChauffeurTripItem trip;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.departureCity,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.mobiliYellow.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.mobiliYellow,
                  size: 18,
                ),
              ),
              Expanded(
                child: Text(
                  trip.arrivalCity,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: 'Départ',
                  value: trip.formattedDate,
                ),
              ),
              const SizedBox(width: 10),
              if (trip.vehiculePlateNumber != null)
                Expanded(
                  child: _InfoChip(
                    icon: Icons.directions_bus_rounded,
                    label: 'Véhicule',
                    value: trip.vehiculePlateNumber!,
                  ),
                ),
            ],
          ),
          if (trip.boardingPoint != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.mobiliYellow,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  trip.boardingPoint!,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _StatusBadge(status: trip.status),
              const Spacer(),
              // Bouton Voir détails
              OutlinedButton.icon(
                onPressed: onDetail,
                icon: const Icon(Icons.visibility_rounded, size: 15),
                label: const Text('Détails', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  side: BorderSide(
                    color: AppColors.white.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (trip.isInProgress || trip.isUpcoming)
                ElevatedButton.icon(
                  onPressed: () =>
                      context.go('/chauffeur/scanner?tripId=${trip.id}'),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text('Scanner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliYellow,
                    foregroundColor: AppColors.mobiliBlueDeep,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card trajet (liste)
// ─────────────────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onDetail,
    this.isHistory = false,
  });
  final ChauffeurTripItem trip;
  final VoidCallback onDetail;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isHistory
                  ? AppColors.gray100
                  : AppColors.mobiliBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_bus_rounded,
              color: isHistory ? AppColors.gray400 : AppColors.mobiliBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.route,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mobiliBlueDeep,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  trip.formattedDate,
                  style: const TextStyle(
                    color: AppColors.gray400,
                    fontSize: 12,
                  ),
                ),
                if (trip.vehiculePlateNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    trip.vehiculePlateNumber!,
                    style: const TextStyle(
                      color: AppColors.gray400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusBadge(status: trip.status),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onDetail,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mobiliBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.mobiliBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 13,
                        color: AppColors.mobiliBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Voir',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mobiliBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.mobiliBlue),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.mobiliBlueDeep,
        ),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  (String, Color, Color) _config(String status) {
    switch (status.toUpperCase()) {
      case 'EN_COURS':
        return (
          'En cours',
          AppColors.stationGreen.withValues(alpha: 0.15),
          AppColors.stationGreen,
        );
      case 'PLANIFIE':
      case 'PROGRAMMÉ':
      case 'PROGRAMME':
      case 'ASSIGNED':
        return (
          'Planifié',
          AppColors.mobiliBlue.withValues(alpha: 0.12),
          AppColors.mobiliBlue,
        );
      case 'TERMINÉ':
      case 'TERMINE':
      case 'COMPLETED':
        return ('Terminé', AppColors.gray100, AppColors.gray500);
      case 'ANNULÉ':
      case 'ANNULE':
      case 'CANCELLED':
        return ('Annulé', AppColors.dangerSoft, AppColors.danger);
      default:
        return (status, AppColors.gray100, AppColors.gray500);
    }
  }
}

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
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: AppColors.gray500)),
            ],
          ),
        ),
      );
}

class _RecentBookingCard extends StatelessWidget {
  const _RecentBookingCard({required this.booking});
  final PartnerRecentBooking booking;

  @override
  Widget build(BuildContext context) => Container(
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.mobiliBlueFog,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(booking.displayInitial,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: AppColors.mobiliBlue, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.mobiliBlueDeep, fontSize: 13)),
                  Text(booking.tripRoute,
                      style: const TextStyle(fontSize: 11, color: AppColors.gray400)),
                ],
              ),
            ),
            Text(booking.formattedAmount,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.mobiliBlueDeep, fontSize: 12)),
          ],
        ),
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.white.withValues(alpha: 0.15)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mobiliYellow),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
