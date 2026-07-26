import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_period_selector.dart';

class LoginStatsDetailPage extends ConsumerStatefulWidget {
  const LoginStatsDetailPage({super.key});
  @override
  ConsumerState<LoginStatsDetailPage> createState() =>
      _LoginStatsDetailPageState();
}

class _LoginStatsDetailPageState extends ConsumerState<LoginStatsDetailPage> {
  AdminStatsPeriod _period = kPeriodWeek;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dailyLoginStatsProvider(_period));
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Connexions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          AdminPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
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
              data: (login) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: KpiCard(
                          icon: Icons.login_rounded,
                          label: "Aujourd'hui",
                          value: '${login.todayTotalLogins}',
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.person_rounded,
                          label: 'Uniques',
                          value: '${login.todayUniqueUsers}',
                          color: AppColors.stationGreen,
                        ),
                      ),
                    ],
                  ),
                  if (login.history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ChartCard(
                      title: 'Connexions — ${_period.label()}',
                      child: SizedBox(
                        height: 200,
                        child: AdminLineChartWidget(
                          entries: login.history,
                          getValue: (e) =>
                              (e as DayEntry).totalLogins.toDouble(),
                          getDate: (e) => (e as DayEntry).date,
                          color: AppColors.mobiliBlue,
                          showTooltip: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ChartCard(
                      title: 'Utilisateurs uniques',
                      child: SizedBox(
                        height: 160,
                        child: AdminLineChartWidget(
                          entries: login.history,
                          getValue: (e) =>
                              (e as DayEntry).uniqueUsers.toDouble(),
                          getDate: (e) => (e as DayEntry).date,
                          color: AppColors.stationGreen,
                          showTooltip: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AdminTableCard(
                      headers: const ['Date', 'Total', 'Uniques'],
                      rows: login.history.reversed
                          .take(30)
                          .map(
                            (e) => [
                              e.date,
                              '${e.totalLogins}',
                              '${e.uniqueUsers}',
                            ],
                          )
                          .toList(),
                      colors: const [
                        null,
                        AppColors.mobiliBlue,
                        AppColors.stationGreen,
                      ],
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
}
