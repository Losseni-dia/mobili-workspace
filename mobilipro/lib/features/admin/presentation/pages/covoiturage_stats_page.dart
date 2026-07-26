import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_export_helpers.dart';
import '../widgets/admin_period_selector.dart';
import 'admin_gestion_page_v2.dart'

show CovoiturageSoloDriver, adminCovoiturageDriversProvider, UserDetailPage;

class CovoiturageStatsDetailPage extends ConsumerStatefulWidget {
  const CovoiturageStatsDetailPage({super.key});
  @override
  ConsumerState<CovoiturageStatsDetailPage> createState() =>
      _CovoiturageStatsDetailPageState();
}

class _CovoiturageStatsDetailPageState
    extends ConsumerState<CovoiturageStatsDetailPage> {
  AdminStatsPeriod _period = kPeriodMonth;
  String _search = '';
  String _kycFilter = 'TOUS';
  String _statusFilter = 'TOUS';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(covoiturageStatsProvider(_period));
    final driversAsync = ref.watch(adminCovoiturageDriversProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Covoiturage',
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
              data: (stats) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: KpiCard(
                          icon: Icons.person_add_rounded,
                          label: "Aujourd'hui",
                          value: '${stats.todayRegistrations}',
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.directions_car_rounded,
                          label: 'Total chauffeurs',
                          value: '${stats.totalDrivers}',
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                    ],
                  ),
                  if (stats.history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ChartCard(
                      title: 'Historique — ${_period.label()}',
                      child: SizedBox(
                        height: 200,
                        child: AdminLineChartWidget(
                          entries: stats.history,
                          getValue: (e) =>
                              (e as RegistrationDayEntry).count.toDouble(),
                          getDate: (e) => (e as RegistrationDayEntry).date,
                          color: AppColors.warning,
                          showTooltip: true,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Chauffeurs covoiturage',
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
                      hintText: 'Rechercher un chauffeur...',
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
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _kycFilter,
                          decoration: InputDecoration(
                            labelText: 'Statut KYC',
                            labelStyle: const TextStyle(fontSize: 11),
                            filled: true,
                            fillColor: AppColors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.gray200,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mobiliBlueDeep,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'TOUS',
                              child: Text('Tous'),
                            ),
                            DropdownMenuItem(
                              value: 'PENDING',
                              child: Text('En attente'),
                            ),
                            DropdownMenuItem(
                              value: 'APPROVED',
                              child: Text('Approuvé'),
                            ),
                            DropdownMenuItem(
                              value: 'REJECTED',
                              child: Text('Rejeté'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _kycFilter = v ?? 'TOUS';
                            _pageSize = 20;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: 'Compte',
                            labelStyle: const TextStyle(fontSize: 11),
                            filled: true,
                            fillColor: AppColors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.gray200,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mobiliBlueDeep,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'TOUS',
                              child: Text('Tous'),
                            ),
                            DropdownMenuItem(
                              value: 'ACTIF',
                              child: Text('Actifs'),
                            ),
                            DropdownMenuItem(
                              value: 'INACTIF',
                              child: Text('Inactifs'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _statusFilter = v ?? 'TOUS';
                            _pageSize = 20;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  driversAsync.when(
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
                 data: (all) {
                      var filtered = all;
                      filtered = filtered
                          .where(
                            (d) =>
                                d.createdAt != null &&
                                !d.createdAt!.isBefore(_period.fromAsDate) &&
                                !d.createdAt!.isAfter(_period.toAsDate),
                          )
                          .toList();
                      if (_kycFilter != 'TOUS') {
                        filtered = filtered
                            .where((d) => d.kycStatus == _kycFilter)
                            .toList();
                      }
                      if (_statusFilter == 'ACTIF') {
                        filtered = filtered.where((d) => d.enabled).toList();
                      }
                      if (_statusFilter == 'INACTIF') {
                        filtered = filtered.where((d) => !d.enabled).toList();
                      }
                      if (_search.isNotEmpty) {
                        final q = _search.toLowerCase();
                        filtered = filtered
                            .where(
                              (d) =>
                                  d.fullName.toLowerCase().contains(q) ||
                                  (d.email ?? '').toLowerCase().contains(q),
                            )
                            .toList();
                      }
                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Aucun chauffeur trouvé',
                              style: TextStyle(color: AppColors.gray400),
                            ),
                          ),
                        );
                      }
                      final visible = filtered.take(_pageSize).toList();
                      final hasMore = filtered.length > _pageSize;
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${visible.length} / ${filtered.length} chauffeur(s)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    exportCovoiturageCsv(filtered, context),
                                icon: const Icon(
                                  Icons.table_chart_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  'CSV',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ...visible.map((d) {
                            final (kycLabel, kycColor) = switch (d.kycStatus) {
                              'APPROVED' => (
                                'Approuvé',
                                AppColors.stationGreen,
                              ),
                              'PENDING' => ('En attente', AppColors.warning),
                              'REJECTED' => ('Rejeté', AppColors.danger),
                              _ => ('—', AppColors.gray400),
                            };
                            final accountLabel = d.enabled
                                ? 'Actif'
                                : 'Inactif';
                            final accountColor = d.enabled
                                ? AppColors.stationGreen
                                : AppColors.danger;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserDetailPage(
                                      userId: d.id,
                                      displayName: d.fullName,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: kycColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d.fullName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: AppColors.mobiliBlueDeep,
                                              ),
                                            ),
                                            if (d.email != null)
                                              Text(
                                                d.email!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.gray500,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kycColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              kycLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: kycColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: accountColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              accountLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: accountColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.gray300,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (hasMore)
                            LoadMoreButton(
                              remaining: filtered.length - _pageSize,
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
