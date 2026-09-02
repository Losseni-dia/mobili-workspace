import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../pages/admin_gestion_page_v2.dart' show adminPartnersProvider;
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_period_selector.dart' show AdminStatsPeriod;

/// "Stats métier" — vue app du même écran web (admin-business) : billets vendus (jamais des
/// réservations), trajets actifs, CA, répartition canal (Via Mobili/guichet), ce que Mobili
/// retient (forfait/commission/net), courbe de croissance, top trajets par volume/rentabilité.
/// Filtres gare + compagnie, période Jour/Semaine/Mois/Année/Intervalle/Date précise — bornes
/// calendaires calculées ici (jamais une fenêtre glissante plafonnée à "maintenant", voir
/// tripStatsProvider dans admin_stats_models.dart pour la justification complète).
class TripStatsDetailPage extends ConsumerStatefulWidget {
  const TripStatsDetailPage({super.key});
  @override
  ConsumerState<TripStatsDetailPage> createState() =>
      _TripStatsDetailPageState();
}

enum _QuickPreset { day, week, month, year, interval, exact }

class _TripStatsDetailPageState extends ConsumerState<TripStatsDetailPage> {
  AdminStatsPeriod _period = _weekRange();
  _QuickPreset _preset = _QuickPreset.week;
  int? _stationId;
  int? _partnerId;
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
    final args = (period: _period, stationId: _stationId, partnerId: _partnerId);
    final async = ref.watch(tripStatsProvider(args));
    final stationsAsync = ref.watch(adminStationOptionsProvider);
    final partnersAsync = ref.watch(adminPartnersProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Stats métier',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          _PeriodBar(preset: _preset, onPreset: _setPreset, onInterval: _pickInterval, onExact: _pickExactDate),
          _FiltersBar(
            stations: stationsAsync.valueOrNull ?? const [],
            partners: partnersAsync.valueOrNull,
            stationId: _stationId,
            partnerId: _partnerId,
            onStationChanged: (v) => setState(() => _stationId = v),
            onPartnerChanged: (v) => setState(() => _partnerId = v),
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
                  RevenueCard(revenue: trip.netCompanyFcfa, subtitle: 'net compagnies'),
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

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.stations,
    required this.partners,
    required this.stationId,
    required this.partnerId,
    required this.onStationChanged,
    required this.onPartnerChanged,
  });
  final List<AdminStationOption> stations;
  final List<dynamic>? partners;
  final int? stationId;
  final int? partnerId;
  final ValueChanged<int?> onStationChanged;
  final ValueChanged<int?> onPartnerChanged;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.white,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Row(
      children: [
        Expanded(
          child: _dropdown<int>(
            icon: Icons.directions_bus_filled_rounded,
            value: stationId,
            hint: 'Toutes les gares',
            items: stations
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: onStationChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dropdown<int>(
            icon: Icons.business_rounded,
            value: partnerId,
            hint: 'Toutes les compagnies',
            items: (partners ?? const [])
                .map<DropdownMenuItem<int>>(
                  (p) => DropdownMenuItem(value: p.id as int, child: Text(p.name as String, overflow: TextOverflow.ellipsis)),
                )
                .toList(),
            onChanged: onPartnerChanged,
          ),
        ),
      ],
    ),
  );

  Widget _dropdown<T>({
    required IconData icon,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.gray200),
      borderRadius: BorderRadius.circular(10),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        isExpanded: true,
        value: value,
        hint: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.gray500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.gray500), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        items: [
          DropdownMenuItem<T>(value: null, child: Text(hint, style: const TextStyle(fontSize: 12))),
          ...items,
        ],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: AppColors.mobiliBlueDeep),
      ),
    ),
  );
}
