import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_filter_chip.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_export_helpers.dart';
import '../widgets/admin_period_selector.dart';

/// Réservation "confirmée" = vente effective (en ligne ou au guichet) — exclut
/// PENDING (pas encore payée) et CANCELLED. Même formule que côté partenaire/gare.
bool _isConfirmedBooking(AdminBookingListItem b) =>
    b.status == 'CONFIRMED' || b.status == 'OFFLINE_SALE';

class TripStatsDetailPage extends ConsumerStatefulWidget {
  const TripStatsDetailPage({super.key});
  @override
  ConsumerState<TripStatsDetailPage> createState() =>
      _TripStatsDetailPageState();
}

class _TripStatsDetailPageState extends ConsumerState<TripStatsDetailPage> {
  AdminStatsPeriod _period = kPeriodWeek;
  String _search = '';
  String _statusFilter = 'CONFIRME';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminBookingListItem> _applyStatusFilter(List<AdminBookingListItem> bookings) =>
      _statusFilter == 'CONFIRME'
          ? bookings.where(_isConfirmedBooking).toList()
          : bookings.where((b) => b.status == 'CANCELLED').toList();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripStatsProvider(_period));
    final listAsync = ref.watch(
      bookingListProvider((period: _period, search: _search)),
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Réservations',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          AdminPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() {
              _period = p;
              _pageSize = 20;
            }),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (trip) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: KpiCard(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Réservations',
                          value: '${trip.totalBookings}',
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.directions_bus_rounded,
                          label: 'Trajets actifs',
                          value: '${trip.activeTripCount}',
                          color: AppColors.stationGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: KpiCard(
                          icon: Icons.payments_rounded,
                          label: 'Revenus FCFA',
                          value:
                              '${NumberFormat('#,###').format(trip.totalRevenueFcfa)} F',
                          color: AppColors.proGold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.trending_up_rounded,
                          label: 'Moy./résa.',
                          value:
                              '${NumberFormat('#,###').format(trip.avgRevenuePerBooking)} F',
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  if (trip.top10ByRevenue.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ChartCard(
                      title: 'Top trajets par revenus',
                      child: SizedBox(
                        height: 220,
                        child: AdminHorizontalBarChart(
                          entries: trip.top10ByRevenue.take(5).toList(),
                          showRevenue: true,
                        ),
                      ),
                    ),
                  ],
                  if (trip.top10ByBookings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ChartCard(
                      title: 'Top trajets par réservations',
                      child: SizedBox(
                        height: 220,
                        child: AdminHorizontalBarChart(
                          entries: trip.top10ByBookings.take(5).toList(),
                          showRevenue: false,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Liste des réservations',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.mobiliBlueDeep,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() {
                      _search = v;
                      _pageSize = 20;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Rechercher référence ou client...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.gray200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      StatusFilterChip(
                        label: 'Confirmé',
                        selected: _statusFilter == 'CONFIRME',
                        onTap: () => setState(() {
                          _statusFilter = 'CONFIRME';
                          _pageSize = 20;
                        }),
                      ),
                      const SizedBox(width: 8),
                      StatusFilterChip(
                        label: 'Annulé',
                        selected: _statusFilter == 'ANNULE',
                        onTap: () => setState(() {
                          _statusFilter = 'ANNULE';
                          _pageSize = 20;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  listAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                    ),
                    error: (e, _) => Text(
                      'Erreur liste : $e',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    data: (allBookings) {
                      final list = _applyStatusFilter(allBookings);
                      // Montant confirmé — jamais influencé par le filtre affiché.
                      final confirmedAmount = allBookings
                          .where(_isConfirmedBooking)
                          .fold<double>(0, (s, b) => s + b.totalPrice);
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Aucune réservation trouvée',
                              style: TextStyle(color: AppColors.gray400),
                            ),
                          ),
                        );
                      }
                      final visible = list.take(_pageSize).toList();
                      final hasMore = list.length > _pageSize;
                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.payments_rounded,
                                  color: AppColors.stationGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${confirmedAmount.toStringAsFixed(0)} F',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.mobiliBlueDeep,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'confirmé',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${visible.length} / ${list.length} réservation(s)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () =>
                                        exportBookingsCsv(list, context),
                                    icon: const Icon(
                                      Icons.table_chart_rounded,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'CSV',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        exportBookingsPdf(list, context),
                                    icon: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'PDF',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...visible.map(
                            (b) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gray200),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.reference,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: AppColors.mobiliBlueDeep,
                                          ),
                                        ),
                                        Text(
                                          '${b.customerName} — ${b.route} (${b.stationName})',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.gray500,
                                          ),
                                        ),
                                        Text(
                                          'Résa ${DateFormat('dd/MM/yy HH:mm').format(b.bookingDate)}'
                                          '${b.departureDateTime != null ? ' · Voyage ${DateFormat('dd/MM/yy HH:mm').format(b.departureDateTime!)}' : ''}'
                                          ' — ${b.numberOfSeats} place(s)',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.gray400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${b.totalPrice.toStringAsFixed(0)} F',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.proGold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (hasMore)
                            LoadMoreButton(
                              remaining: list.length - _pageSize,
                              onTap: () => setState(() => _pageSize += 20),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
