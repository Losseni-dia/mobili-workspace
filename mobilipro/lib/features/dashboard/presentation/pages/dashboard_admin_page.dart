import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/shared/widgets/admin_search_page.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES (identiques v3)
// ═══════════════════════════════════════════════════════════════════════════

class AdminStats {
  const AdminStats({required this.totalUsers, required this.totalPartners, required this.totalTrips, required this.activeBookings, required this.totalRevenue});
  final int totalUsers, totalPartners, totalTrips, activeBookings;
  final double totalRevenue;
  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
    totalUsers: (j['totalUsers'] as num?)?.toInt() ?? 0,
    totalPartners: (j['totalPartners'] as num?)?.toInt() ?? 0,
    totalTrips: (j['totalTrips'] as num?)?.toInt() ?? 0,
    activeBookings: (j['activeBookings'] as num?)?.toInt() ?? 0,
    totalRevenue: (j['totalRevenue'] as num?)?.toDouble() ?? 0,
  );
}

class DailyLoginStats {
  const DailyLoginStats({required this.todayTotalLogins, required this.todayUniqueUsers, required this.history});
  final int todayTotalLogins, todayUniqueUsers;
  final List<DayEntry> history;
  factory DailyLoginStats.fromJson(Map<String, dynamic> j) => DailyLoginStats(
    todayTotalLogins: (j['todayTotalLogins'] as num?)?.toInt() ?? 0,
    todayUniqueUsers: (j['todayUniqueUsers'] as num?)?.toInt() ?? 0,
    history: (j['history'] as List<dynamic>? ?? []).map((e) => DayEntry.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class DayEntry {
  const DayEntry({required this.date, required this.totalLogins, required this.uniqueUsers});
  final String date;
  final int totalLogins, uniqueUsers;
  factory DayEntry.fromJson(Map<String, dynamic> j) => DayEntry(
    date: j['date'] as String? ?? '',
    totalLogins: (j['totalLogins'] as num?)?.toInt() ?? 0,
    uniqueUsers: (j['uniqueUsers'] as num?)?.toInt() ?? 0,
  );
}

class TripStats {
  const TripStats({required this.totalBookings, required this.totalRevenueFcfa, required this.activeTripCount, required this.avgRevenuePerBooking, required this.top10ByBookings, required this.top10ByRevenue, required this.period});
  final int totalBookings, activeTripCount;
  final double totalRevenueFcfa, avgRevenuePerBooking;
  final List<TripStatEntry> top10ByBookings, top10ByRevenue;
  final String period;
  factory TripStats.fromJson(Map<String, dynamic> j, String period) => TripStats(
    totalBookings: (j['totalBookings'] as num?)?.toInt() ?? 0,
    totalRevenueFcfa: (j['totalRevenueFcfa'] as num?)?.toDouble() ?? 0,
    activeTripCount: (j['activeTripCount'] as num?)?.toInt() ?? 0,
    avgRevenuePerBooking: (j['avgRevenuePerBooking'] as num?)?.toDouble() ?? 0,
    top10ByBookings: (j['top10ByBookings'] as List<dynamic>? ?? []).map((e) => TripStatEntry.fromJson(e as Map<String, dynamic>)).toList(),
    top10ByRevenue: (j['top10ByRevenue'] as List<dynamic>? ?? []).map((e) => TripStatEntry.fromJson(e as Map<String, dynamic>)).toList(),
    period: period,
  );
}

class TripStatEntry {
  const TripStatEntry({required this.rank, required this.tripId, required this.route, required this.partnerName, required this.bookingCount, required this.revenueFcfa});
  final int rank, tripId, bookingCount;
  final String route, partnerName;
  final double revenueFcfa;
  factory TripStatEntry.fromJson(Map<String, dynamic> j) => TripStatEntry(
    rank: (j['rank'] as num?)?.toInt() ?? 0,
    tripId: (j['tripId'] as num?)?.toInt() ?? 0,
    route: j['route'] as String? ?? '',
    partnerName: j['partnerName'] as String? ?? '',
    bookingCount: (j['bookingCount'] as num?)?.toInt() ?? 0,
    revenueFcfa: (j['revenueFcfa'] as num?)?.toDouble() ?? 0,
  );
}

class RegistrationStats {
  const RegistrationStats({required this.todayRegistrations, required this.totalUsers, required this.history});
  final int todayRegistrations, totalUsers;
  final List<RegistrationDayEntry> history;
  factory RegistrationStats.fromJson(Map<String, dynamic> j) => RegistrationStats(
    todayRegistrations: (j['todayRegistrations'] as num?)?.toInt() ?? 0,
    totalUsers: (j['totalUsers'] as num?)?.toInt() ?? 0,
    history: (j['history'] as List<dynamic>? ?? []).map((e) => RegistrationDayEntry.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class RegistrationDayEntry {
  const RegistrationDayEntry({required this.date, required this.count});
  final String date;
  final int count;
  factory RegistrationDayEntry.fromJson(Map<String, dynamic> j) => RegistrationDayEntry(
    date: j['date'] as String? ?? '',
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final res = await ApiClient.instance.dio.get<Map<String, dynamic>>('/admin/stats');
  return AdminStats.fromJson(res.data!);
});

final dailyLoginStatsProvider = FutureProvider.autoDispose.family<DailyLoginStats, int>((ref, days) async {
  final res = await ApiClient.instance.dio.get<Map<String, dynamic>>('/admin/stats/daily-logins', queryParameters: {'days': days});
  return DailyLoginStats.fromJson(res.data!);
});

final tripStatsProvider = FutureProvider.autoDispose.family<TripStats, String>((ref, period) async {
  final res = await ApiClient.instance.dio.get<Map<String, dynamic>>('/admin/stats/trip-analytics', queryParameters: {'period': period});
  return TripStats.fromJson(res.data!, period);
});

final registrationStatsProvider = FutureProvider.autoDispose.family<RegistrationStats, int>((ref, days) async {
  final res = await ApiClient.instance.dio.get<Map<String, dynamic>>('/admin/stats/registrations', queryParameters: {'days': days});
  return RegistrationStats.fromJson(res.data!);
});

// ═══════════════════════════════════════════════════════════════════════════
// PAGE DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text('Dashboard Admin', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSearchPage()))),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () {
            ref.invalidate(adminStatsProvider);
            ref.invalidate(dailyLoginStatsProvider);
            ref.invalidate(tripStatsProvider);
            ref.invalidate(registrationStatsProvider);
          }),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          ref.invalidate(dailyLoginStatsProvider);
          ref.invalidate(tripStatsProvider);
          ref.invalidate(registrationStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI
            const _SectionTitle(title: 'Vue globale'),
            const SizedBox(height: 10),
            statsAsync.when(
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: '$e'),
              data: (stats) => Column(children: [
                Row(children: [
                  Expanded(child: _KpiCard(icon: Icons.people_rounded, label: 'Utilisateurs', value: '${stats.totalUsers}', color: AppColors.mobiliBlue)),
                  const SizedBox(width: 10),
                  Expanded(child: _KpiCard(icon: Icons.business_rounded, label: 'Partenaires', value: '${stats.totalPartners}', color: AppColors.proGold)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _KpiCard(icon: Icons.directions_bus_rounded, label: 'Trajets', value: '${stats.totalTrips}', color: AppColors.stationGreen)),
                  const SizedBox(width: 10),
                  Expanded(child: _KpiCard(icon: Icons.bookmark_rounded, label: 'Réservations', value: '${stats.activeBookings}', color: AppColors.warning)),
                ]),
                const SizedBox(height: 10),
                _RevenueCard(revenue: stats.totalRevenue),
              ]),
            ),

            const SizedBox(height: 20),

            // Inscriptions
            _SectionHeader(title: 'Inscriptions', onDetail: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationStatsDetailPage()))),
            const SizedBox(height: 10),
            _RegistrationSummaryCard(),

            const SizedBox(height: 20),

            // Connexions
            _SectionHeader(title: 'Connexions', onDetail: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginStatsDetailPage()))),
            const SizedBox(height: 10),
            _LoginSummaryCard(),

            const SizedBox(height: 20),

            // Trajets
            _SectionHeader(title: 'Statistiques trajets', onDetail: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripStatsDetailPage()))),
            const SizedBox(height: 10),
            _TripStatsSummaryCard(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTES RÉSUMÉ
// ═══════════════════════════════════════════════════════════════════════════

class _RegistrationSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(registrationStatsProvider(30));
    return async.when(
      loading: () => const _LoadingCard(),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (stats) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationStatsDetailPage())),
        child: _SummaryCard(children: [
          Row(children: [
            Expanded(child: _MiniKpi(label: "Aujourd'hui", value: '${stats.todayRegistrations}', color: AppColors.stationGreen)),
            const SizedBox(width: 10),
            Expanded(child: _MiniKpi(label: 'Total', value: '${stats.totalUsers}', color: AppColors.mobiliBlue)),
          ]),
          if (stats.history.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(height: 80, child: _LineChartWidget(
              entries: stats.history.length > 7 ? stats.history.sublist(stats.history.length - 7) : stats.history,
              getValue: (e) => (e as RegistrationDayEntry).count.toDouble(),
              getDate: (e) => (e as RegistrationDayEntry).date,
              color: AppColors.stationGreen,
            )),
          ],
          const SizedBox(height: 8),
          _SeeMoreRow(),
        ]),
      ),
    );
  }
}

class _LoginSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyLoginStatsProvider(7));
    return async.when(
      loading: () => const _LoadingCard(),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (login) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginStatsDetailPage())),
        child: _SummaryCard(children: [
          Row(children: [
            Expanded(child: _MiniKpi(label: "Aujourd'hui", value: '${login.todayTotalLogins}', color: AppColors.mobiliBlue)),
            const SizedBox(width: 10),
            Expanded(child: _MiniKpi(label: 'Uniques', value: '${login.todayUniqueUsers}', color: AppColors.stationGreen)),
          ]),
          if (login.history.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(height: 80, child: _LineChartWidget(
              entries: login.history.length > 7 ? login.history.sublist(login.history.length - 7) : login.history,
              getValue: (e) => (e as DayEntry).totalLogins.toDouble(),
              getDate: (e) => (e as DayEntry).date,
              color: AppColors.mobiliBlue,
            )),
          ],
          const SizedBox(height: 8),
          _SeeMoreRow(),
        ]),
      ),
    );
  }
}

class _TripStatsSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripStatsProvider('WEEK'));
    return async.when(
      loading: () => const _LoadingCard(),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (trip) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripStatsDetailPage())),
        child: _SummaryCard(children: [
          const Text('7 derniers jours', style: TextStyle(fontSize: 11, color: AppColors.gray400, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniKpi(label: 'Réservations', value: '${trip.totalBookings}', color: AppColors.mobiliBlue)),
            const SizedBox(width: 10),
            Expanded(child: _MiniKpi(label: 'Trajets actifs', value: '${trip.activeTripCount}', color: AppColors.stationGreen)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniKpi(label: 'Revenus', value: '${NumberFormat('#,###').format(trip.totalRevenueFcfa)} F', color: AppColors.proGold)),
            const SizedBox(width: 10),
            Expanded(child: _MiniKpi(label: 'Moy./résa.', value: '${NumberFormat('#,###').format(trip.avgRevenuePerBooking)} F', color: AppColors.warning)),
          ]),
          if (trip.top10ByRevenue.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(height: 160, child: _HorizontalBarChart(entries: trip.top10ByRevenue.take(5).toList(), showRevenue: true)),
          ],
          const SizedBox(height: 8),
          _SeeMoreRow(),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGES DÉTAIL
// ═══════════════════════════════════════════════════════════════════════════

class RegistrationStatsDetailPage extends ConsumerStatefulWidget {
  const RegistrationStatsDetailPage({super.key});
  @override
  ConsumerState<RegistrationStatsDetailPage> createState() => _RegistrationStatsDetailPageState();
}

class _RegistrationStatsDetailPageState extends ConsumerState<RegistrationStatsDetailPage> {
  int _days = 30;
  static const _options = [7, 30, 90];
  static const _labels = ['7 jours', '1 mois', '3 mois'];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(registrationStatsProvider(_days));
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(backgroundColor: AppColors.mobiliBlue, foregroundColor: AppColors.white, title: const Text('Inscriptions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
      body: Column(children: [
        _PeriodSelector(options: _options, labels: _labels, selected: _days, onSelected: (v) => setState(() => _days = v)),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
          error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: AppColors.danger))),
          data: (stats) => ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: _KpiCard(icon: Icons.person_add_rounded, label: "Aujourd'hui", value: '${stats.todayRegistrations}', color: AppColors.stationGreen)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.people_rounded, label: 'Total', value: '${stats.totalUsers}', color: AppColors.mobiliBlue)),
            ]),
            if (stats.history.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Historique ${_labels[_options.indexOf(_days)]}',
                child: SizedBox(height: 200, child: _LineChartWidget(
                  entries: stats.history,
                  getValue: (e) => (e as RegistrationDayEntry).count.toDouble(),
                  getDate: (e) => (e as RegistrationDayEntry).date,
                  color: AppColors.stationGreen,
                  showTooltip: true,
                )),
              ),
              const SizedBox(height: 16),
              _TableCard(
                headers: ['Date', 'Inscriptions'],
                rows: stats.history.reversed.map((e) => [e.date, '${e.count}']).toList(),
                colors: [null, AppColors.stationGreen],
              ),
            ],
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }
}

class LoginStatsDetailPage extends ConsumerStatefulWidget {
  const LoginStatsDetailPage({super.key});
  @override
  ConsumerState<LoginStatsDetailPage> createState() => _LoginStatsDetailPageState();
}

class _LoginStatsDetailPageState extends ConsumerState<LoginStatsDetailPage> {
  int _days = 7;
  static const _options = [7, 30, 90];
  static const _labels = ['7 jours', '1 mois', '3 mois'];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dailyLoginStatsProvider(_days));
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(backgroundColor: AppColors.mobiliBlue, foregroundColor: AppColors.white, title: const Text('Connexions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
      body: Column(children: [
        _PeriodSelector(options: _options, labels: _labels, selected: _days, onSelected: (v) => setState(() => _days = v)),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
          error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: AppColors.danger))),
          data: (login) => ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: _KpiCard(icon: Icons.login_rounded, label: "Aujourd'hui", value: '${login.todayTotalLogins}', color: AppColors.mobiliBlue)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.person_rounded, label: 'Uniques', value: '${login.todayUniqueUsers}', color: AppColors.stationGreen)),
            ]),
            if (login.history.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Connexions — ${_labels[_options.indexOf(_days)]}',
                child: SizedBox(height: 200, child: _LineChartWidget(
                  entries: login.history,
                  getValue: (e) => (e as DayEntry).totalLogins.toDouble(),
                  getDate: (e) => (e as DayEntry).date,
                  color: AppColors.mobiliBlue,
                  showTooltip: true,
                )),
              ),
              const SizedBox(height: 8),
              _ChartCard(
                title: 'Utilisateurs uniques',
                child: SizedBox(height: 160, child: _LineChartWidget(
                  entries: login.history,
                  getValue: (e) => (e as DayEntry).uniqueUsers.toDouble(),
                  getDate: (e) => (e as DayEntry).date,
                  color: AppColors.stationGreen,
                  showTooltip: true,
                )),
              ),
              const SizedBox(height: 16),
              _TableCard(
                headers: ['Date', 'Total', 'Uniques'],
                rows: login.history.reversed.take(30).map((e) => [e.date, '${e.totalLogins}', '${e.uniqueUsers}']).toList(),
                colors: [null, AppColors.mobiliBlue, AppColors.stationGreen],
              ),
            ],
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }
}

class TripStatsDetailPage extends ConsumerStatefulWidget {
  const TripStatsDetailPage({super.key});
  @override
  ConsumerState<TripStatsDetailPage> createState() => _TripStatsDetailPageState();
}

class _TripStatsDetailPageState extends ConsumerState<TripStatsDetailPage> {
  String _period = 'WEEK';
  static const _periods = ['DAY', 'WEEK', 'MONTH'];
  static const _periodLabels = ["Aujourd'hui", '7 jours', '1 mois'];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripStatsProvider(_period));
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(backgroundColor: AppColors.mobiliBlue, foregroundColor: AppColors.white, title: const Text('Trajets', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
      body: Column(children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: _periods.asMap().entries.map((e) {
            final sel = _period == e.value;
            return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
              onTap: () => setState(() => _period = e.value),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: sel ? AppColors.mobiliBlue : AppColors.gray100, borderRadius: BorderRadius.circular(20)),
                child: Text(_periodLabels[e.key], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppColors.white : AppColors.gray600)),
              ),
            ));
          }).toList()),
        ),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
          error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: AppColors.danger))),
          data: (trip) => ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: _KpiCard(icon: Icons.confirmation_number_rounded, label: 'Réservations', value: '${trip.totalBookings}', color: AppColors.mobiliBlue)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.directions_bus_rounded, label: 'Trajets actifs', value: '${trip.activeTripCount}', color: AppColors.stationGreen)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _KpiCard(icon: Icons.payments_rounded, label: 'Revenus FCFA', value: '${NumberFormat('#,###').format(trip.totalRevenueFcfa)} F', color: AppColors.proGold)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.trending_up_rounded, label: 'Moy./résa.', value: '${NumberFormat('#,###').format(trip.avgRevenuePerBooking)} F', color: AppColors.warning)),
            ]),
            if (trip.top10ByRevenue.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Top trajets par revenus',
                child: SizedBox(height: 220, child: _HorizontalBarChart(entries: trip.top10ByRevenue.take(5).toList(), showRevenue: true)),
              ),
            ],
            if (trip.top10ByBookings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ChartCard(
                title: 'Top trajets par réservations',
                child: SizedBox(height: 220, child: _HorizontalBarChart(entries: trip.top10ByBookings.take(5).toList(), showRevenue: false)),
              ),
            ],
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRAPHIQUES fl_chart
// ═══════════════════════════════════════════════════════════════════════════

class _LineChartWidget extends StatefulWidget {
  const _LineChartWidget({required this.entries, required this.getValue, required this.getDate, required this.color, this.showTooltip = false});
  final List<dynamic> entries;
  final double Function(dynamic) getValue;
  final String Function(dynamic) getDate;
  final Color color;
  final bool showTooltip;

  @override
  State<_LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<_LineChartWidget> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final spots = widget.entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), widget.getValue(e.value))).toList();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        minY: (minY - (maxY - minY) * 0.1).clamp(0, double.infinity),
        maxY: maxY + (maxY - minY) * 0.1 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.gray100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: widget.entries.length > 14 ? (widget.entries.length / 5).roundToDouble() : 1,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= widget.entries.length) return const SizedBox.shrink();
                final date = widget.getDate(widget.entries[i]);
                final short = date.length >= 5 ? date.substring(5) : date;
                return Text(short, style: const TextStyle(fontSize: 8, color: AppColors.gray400));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: widget.showTooltip,
          touchCallback: (event, response) {
            if (response?.lineBarSpots != null && event is FlTapUpEvent) {
              setState(() => _touchedIndex = response!.lineBarSpots!.first.spotIndex);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.mobiliBlueDeep,
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              '${s.y.toInt()}\n${widget.getDate(widget.entries[s.spotIndex])}',
              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            )).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: widget.color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: widget.entries.length <= 14,
              getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
                radius: _touchedIndex == i ? 5 : 3,
                color: widget.color,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [widget.color.withValues(alpha: 0.25), widget.color.withValues(alpha: 0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalBarChart extends StatefulWidget {
  const _HorizontalBarChart({required this.entries, required this.showRevenue});
  final List<TripStatEntry> entries;
  final bool showRevenue;

  @override
  State<_HorizontalBarChart> createState() => _HorizontalBarChartState();
}

class _HorizontalBarChartState extends State<_HorizontalBarChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final color = widget.showRevenue ? AppColors.proGold : AppColors.mobiliBlue;
    final maxVal = widget.entries.fold<double>(1, (m, e) => widget.showRevenue ? (e.revenueFcfa > m ? e.revenueFcfa : m) : (e.bookingCount > m ? e.bookingCount.toDouble() : m));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent) setState(() => _touchedIndex = response?.spot?.touchedBarGroupIndex);
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.mobiliBlueDeep,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final e = widget.entries[groupIndex];
              final val = widget.showRevenue ? '${NumberFormat('#,###').format(e.revenueFcfa)} F' : '${e.bookingCount} rés.';
              return BarTooltipItem('${e.route}\n$val', const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700));
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= widget.entries.length) return const SizedBox.shrink();
                final route = widget.entries[i].route;
                final parts = route.split(' → ');
                final short = parts.isNotEmpty ? parts[0] : route;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(short.length > 6 ? '${short.substring(0, 6)}…' : short, style: const TextStyle(fontSize: 8, color: AppColors.gray500)),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.gray100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: widget.entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final val = widget.showRevenue ? e.revenueFcfa : e.bookingCount.toDouble();
          final isTouched = _touchedIndex == i;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: val,
              color: isTouched ? color : color.withValues(alpha: 0.75),
              width: isTouched ? 22 : 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxVal * 1.15, color: AppColors.gray100),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ═══════════════════════════════════════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gray200),
      boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gray200),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.mobiliBlueDeep)),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.headers, required this.rows, required this.colors});
  final List<String> headers;
  final List<List<String>> rows;
  final List<Color?> colors;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.gray200)),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: headers.asMap().entries.map((e) => e.key == 0
            ? Expanded(child: Text(e.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gray500)))
            : SizedBox(width: 70, child: Text(e.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gray500), textAlign: TextAlign.right))
        ).toList()),
      ),
      const Divider(height: 1, color: AppColors.gray100),
      ...rows.map((row) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(children: row.asMap().entries.map((e) => e.key == 0
              ? Expanded(child: Text(e.value, style: const TextStyle(fontSize: 12, color: AppColors.mobiliBlueDeep)))
              : SizedBox(width: 70, child: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors[e.key] ?? AppColors.mobiliBlueDeep), textAlign: TextAlign.right))
          ).toList()),
        ),
        const Divider(height: 1, color: AppColors.gray100),
      ])),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.mobiliBlueDeep));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onDetail});
  final String title;
  final VoidCallback onDetail;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.mobiliBlueDeep)),
      TextButton.icon(onPressed: onDetail, icon: const Icon(Icons.open_in_new_rounded, size: 14), label: const Text('Voir détails', style: TextStyle(fontSize: 12)), style: TextButton.styleFrom(foregroundColor: AppColors.mobiliBlue)),
    ],
  );
}

class _SeeMoreRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text('Voir historique complet', style: TextStyle(fontSize: 11, color: AppColors.mobiliBlue, fontWeight: FontWeight.w600)),
      SizedBox(width: 4),
      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.mobiliBlue),
    ],
  );
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.options, required this.labels, required this.selected, required this.onSelected});
  final List<int> options;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(children: options.asMap().entries.map((e) {
      final sel = selected == e.value;
      return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
        onTap: () => onSelected(e.value),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: sel ? AppColors.mobiliBlue : AppColors.gray100, borderRadius: BorderRadius.circular(20)),
          child: Text(labels[e.key], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppColors.white : AppColors.gray600)),
        ),
      ));
    }).toList()),
  );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2)), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))]),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.gray500)),
      ])),
    ]),
  );
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.gray500)),
    ]),
  );
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.revenue});
  final double revenue;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep]), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Revenus totaux', style: TextStyle(color: Colors.white70, fontSize: 12)),
        Text('${NumberFormat('#,###').format(revenue)} FCFA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
      ])),
    ]),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Container(height: 80, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14)), child: const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
    child: Row(children: [const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 12)))]),
  );
}