import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../admin/presentation/models/admin_stats_models.dart'
    show TripStats, TripStatsDayEntry;
import '../../../admin/presentation/widgets/admin_common_widgets.dart';
import '../../../admin/presentation/widgets/admin_period_selector.dart'
    show AdminStatsPeriod;
import '../../providers/partner_shared_providers.dart';

/// Args de partnerTripStatsProvider — station optionnelle (filtre gare, propre au réseau du
/// partenaire connecté). Pas de filtre compagnie : le backend (PartnerTripAnalyticsController)
/// scope déjà tout sur `partnerService.getCurrentPartnerForOperations()`.
typedef PartnerTripStatsArgs = ({AdminStatsPeriod period, int? stationId});

/// Toujours envoyé en period=CUSTOM avec fromAsDate/toAsDate (bornes calendaires), jamais
/// period=WEEK/MONTH laissé au backend — même raison que tripStatsProvider (admin) : une fenêtre
/// glissante plafonnée à "maintenant" est aveugle à toute vente déjà faite pour une date future
/// dans la période. Voir admin_stats_models.dart pour l'historique complet du bug (2026-09-01).
final partnerTripStatsProvider = FutureProvider.autoDispose
    .family<TripStats, PartnerTripStatsArgs>((ref, args) async {
      final f = DateFormat('yyyy-MM-dd');
      final qp = <String, dynamic>{
        'period': 'CUSTOM',
        'fromDate': f.format(args.period.fromDate ?? DateTime.now()),
        'toDate': f.format(args.period.toDate ?? DateTime.now()),
        if (args.stationId != null) 'stationId': args.stationId,
      };
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/partenaire/stats/trip-analytics',
        queryParameters: qp,
      );
      return TripStats.fromJson(res.data!, 'CUSTOM');
    });

/// "Statistiques métier" côté partenaire — vue app parité avec le web (partner-business) et
/// avec la vue admin (bookings_stats_page.dart) : billets vendus (jamais des réservations),
/// trajets actifs, CA, répartition canal (Via Mobili/guichet), ce que Mobili retient
/// (forfait/commission/net), courbe de croissance, top trajets par volume/rentabilité. Filtre
/// gare uniquement (réseau du partenaire) — pas de filtre compagnie, déjà scopé côté backend.
class PartnerBusinessStatsPage extends ConsumerStatefulWidget {
  const PartnerBusinessStatsPage({super.key});
  @override
  ConsumerState<PartnerBusinessStatsPage> createState() =>
      _PartnerBusinessStatsPageState();
}

enum _QuickPreset { day, week, month, year, interval, exact }

class _PartnerBusinessStatsPageState
    extends ConsumerState<PartnerBusinessStatsPage> {
  AdminStatsPeriod _period = _weekRange();
  _QuickPreset _preset = _QuickPreset.week;
  int? _stationId;
  String _growthMetric = 'revenue'; // 'revenue' | 'tickets'

  static AdminStatsPeriod _dayRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (days: 0, fromDate: today, toDate: today);
  }

  static AdminStatsPeriod _weekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return (days: 0, fromDate: monday, toDate: sunday);
  }

  static AdminStatsPeriod _monthRange() {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0);
    return (days: 0, fromDate: first, toDate: last);
  }

  static AdminStatsPeriod _yearRange() {
    final now = DateTime.now();
    return (days: 0, fromDate: DateTime(now.year, 1, 1), toDate: DateTime(now.year, 12, 31));
  }

  void _setPreset(_QuickPreset p) {
    setState(() {
      _preset = p;
      switch (p) {
        case _QuickPreset.day:
          _period = _dayRange();
        case _QuickPreset.week:
          _period = _weekRange();
        case _QuickPreset.month:
          _period = _monthRange();
        case _QuickPreset.year:
          _period = _yearRange();
        case _QuickPreset.interval:
        case _QuickPreset.exact:
          break; // gérés par les pickers ci-dessous
      }
    });
  }

  Future<void> _pickInterval() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 50),
      locale: const Locale('fr', 'FR'),
      initialDateRange: DateTimeRange(
        start: _period.fromDate ?? now.subtract(const Duration(days: 29)),
        end: _period.toDate ?? now,
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.mobiliBlue),
        ),
        child: child!,
      ),
    );
    if (range == null) return;
    setState(() {
      _preset = _QuickPreset.interval;
      _period = (days: 0, fromDate: range.start, toDate: range.end);
    });
  }

  Future<void> _pickExactDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 50),
      locale: const Locale('fr', 'FR'),
      initialDate: _period.fromDate ?? now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.mobiliBlue),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _preset = _QuickPreset.exact;
      _period = (days: 0, fromDate: picked, toDate: picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = (period: _period, stationId: _stationId);
    final async = ref.watch(partnerTripStatsProvider(args));
    final stationsAsync = ref.watch(partnerStationsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Statistiques métier',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          _PeriodBar(preset: _preset, onPreset: _setPreset, onInterval: _pickInterval, onExact: _pickExactDate),
          _StationFilterBar(
            stations: stationsAsync.valueOrNull ?? const [],
            stationId: _stationId,
            onStationChanged: (v) => setState(() => _stationId = v),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: AdminErrorCard(message: 'Erreur : $e'),
              ),
              data: (trip) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: KpiCard(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Billets vendus',
                          value: '${trip.totalTickets}',
                          color: AppColors.mobiliBlue,
                          subtitle: _deltaLabel(trip.ticketsDeltaPercent),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.directions_bus_rounded,
                          label: 'Trajets avec ventes',
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
                          label: 'CA (FCFA)',
                          value: '${NumberFormat('#,###').format(trip.totalRevenueFcfa)} F',
                          color: AppColors.proGold,
                          subtitle: _deltaLabel(trip.revenueDeltaPercent),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.trending_up_rounded,
                          label: 'Panier moyen',
                          value: '${NumberFormat('#,###').format(trip.avgRevenuePerTicket)} F',
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AdminSectionTitle(title: 'Répartition du CA par canal'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: KpiCard(
                          icon: Icons.smartphone_rounded,
                          label: 'Via Mobili',
                          value: '${NumberFormat('#,###').format(trip.revenueOnlineFcfa)} F',
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.confirmation_num_rounded,
                          label: 'Au guichet',
                          value: '${NumberFormat('#,###').format(trip.revenueOfflineFcfa)} F',
                          color: AppColors.stationGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AdminSectionTitle(title: 'Ce que Mobili retient'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: KpiCard(
                          icon: Icons.receipt_long_rounded,
                          label: 'Forfait client',
                          value: '${NumberFormat('#,###').format(trip.totalServiceFeeFcfa)} F',
                          color: AppColors.gray600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.percent_rounded,
                          label: 'Commission',
                          value: '${NumberFormat('#,###').format(trip.totalCommissionFcfa)} F',
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  RevenueCard(revenue: trip.netCompanyFcfa, subtitle: 'net compagnie'),
                  if (trip.timeline.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ChartCard(
                      title: 'Courbe de croissance',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _MetricChip(
                                label: 'CA (FCFA)',
                                selected: _growthMetric == 'revenue',
                                onTap: () => setState(() => _growthMetric = 'revenue'),
                              ),
                              const SizedBox(width: 8),
                              _MetricChip(
                                label: 'Billets',
                                selected: _growthMetric == 'tickets',
                                onTap: () => setState(() => _growthMetric = 'tickets'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 180,
                            child: AdminLineChartWidget(
                              entries: trip.timeline,
                              getValue: (e) => _growthMetric == 'revenue'
                                  ? (e as TripStatsDayEntry).revenueFcfa
                                  : (e as TripStatsDayEntry).ticketCount.toDouble(),
                              getDate: (e) => (e as TripStatsDayEntry).date,
                              color: AppColors.mobiliBlue,
                              showTooltip: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (trip.top10ByRevenue.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ChartCard(
                      title: 'Top trajets — rentabilité (CA)',
                      child: SizedBox(
                        height: 220,
                        child: AdminHorizontalBarChart(
                          entries: trip.top10ByRevenue.take(5).toList(),
                          showRevenue: true,
                        ),
                      ),
                    ),
                  ],
                  if (trip.top10ByTickets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ChartCard(
                      title: 'Top trajets — volume (billets)',
                      child: SizedBox(
                        height: 220,
                        child: AdminHorizontalBarChart(
                          entries: trip.top10ByTickets.take(5).toList(),
                          showRevenue: false,
                        ),
                      ),
                    ),
                  ],
                  if (trip.top10ByTickets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const AdminSectionTitle(title: 'Top 10 — détail'),
                    const SizedBox(height: 10),
                    AdminTableCard(
                      headers: const ['Route', 'Billets', 'CA'],
                      colors: const [null, AppColors.mobiliBlue, AppColors.proGold],
                      rows: trip.top10ByTickets
                          .map(
                            (r) => [
                              '${r.route} (${r.stationName})',
                              '${r.ticketCount}',
                              NumberFormat('#,###').format(r.revenueFcfa),
                            ],
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _deltaLabel(double? pct) {
    if (pct == null) return null;
    final arrow = pct >= 0 ? '▲' : '▼';
    return '$arrow ${pct.abs().toStringAsFixed(1)} % vs période préc.';
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.mobiliBlue : AppColors.gray100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.white : AppColors.gray600,
        ),
      ),
    ),
  );
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.preset,
    required this.onPreset,
    required this.onInterval,
    required this.onExact,
  });
  final _QuickPreset preset;
  final ValueChanged<_QuickPreset> onPreset;
  final VoidCallback onInterval;
  final VoidCallback onExact;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, 'Jour', preset == _QuickPreset.day, () => onPreset(_QuickPreset.day)),
          _chip(context, 'Semaine', preset == _QuickPreset.week, () => onPreset(_QuickPreset.week)),
          _chip(context, 'Mois', preset == _QuickPreset.month, () => onPreset(_QuickPreset.month)),
          _chip(context, 'Année', preset == _QuickPreset.year, () => onPreset(_QuickPreset.year)),
          _chip(context, 'Intervalle', preset == _QuickPreset.interval, onInterval, icon: Icons.date_range_rounded),
          _chip(context, 'Date précise', preset == _QuickPreset.exact, onExact, icon: Icons.today_rounded),
        ],
      ),
    ),
  );

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.mobiliBlue : AppColors.gray100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? AppColors.white : AppColors.gray600),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : AppColors.gray600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StationFilterBar extends StatelessWidget {
  const _StationFilterBar({
    required this.stations,
    required this.stationId,
    required this.onStationChanged,
  });
  final List<StationItem> stations;
  final int? stationId;
  final ValueChanged<int?> onStationChanged;

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gray200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            isExpanded: true,
            value: stationId,
            hint: Row(
              children: [
                const Icon(Icons.directions_bus_filled_rounded, size: 14, color: AppColors.gray500),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Toutes les gares', style: TextStyle(fontSize: 11, color: AppColors.gray500)),
                ),
              ],
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Toutes les gares', style: TextStyle(fontSize: 12))),
              ...stations.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: onStationChanged,
            style: const TextStyle(fontSize: 12, color: AppColors.mobiliBlueDeep),
          ),
        ),
      ),
    );
  }
}
