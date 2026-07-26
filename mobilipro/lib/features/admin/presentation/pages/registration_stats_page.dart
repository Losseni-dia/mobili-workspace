import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_period_selector.dart';
import 'admin_gestion_page_v2.dart'
    show AdminUser, adminUsersProvider, UserDetailPage;
import '../widgets/admin_export_helpers.dart';

class RegistrationStatsDetailPage extends ConsumerStatefulWidget {
  const RegistrationStatsDetailPage({super.key});
  @override
  ConsumerState<RegistrationStatsDetailPage> createState() =>
      _RegistrationStatsDetailPageState();
}

class _RegistrationStatsDetailPageState
    extends ConsumerState<RegistrationStatsDetailPage> {
  AdminStatsPeriod _period = kPeriodMonth;
  String _search = '';
  String _roleFilter = 'TOUS';
  String _statusFilter = 'TOUS';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus(AdminUser u) async {
    try {
      await ApiClient.instance.dio.patch(
        '/admin/users/${u.id}/status',
        queryParameters: {'enabled': !u.enabled},
      );
      ref.invalidate(adminUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              u.enabled ? '${u.fullName} désactivé' : '${u.fullName} activé',
            ),
            backgroundColor: AppColors.stationGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(registrationStatsProvider(_period));
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Utilisateurs',
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
                          color: AppColors.stationGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.people_rounded,
                          label: 'Total',
                          value: '${stats.totalUsers}',
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
                        height: 160,
                        child: AdminLineChartWidget(
                          entries: stats.history,
                          getValue: (e) =>
                              (e as RegistrationDayEntry).count.toDouble(),
                          getDate: (e) => (e as RegistrationDayEntry).date,
                          color: AppColors.stationGreen,
                          showTooltip: true,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Liste des utilisateurs',
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
                      hintText: 'Rechercher un utilisateur...',
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
                          value: _roleFilter,
                          decoration: InputDecoration(
                            labelText: 'Rôle',
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
                              child: Text('Tous les rôles'),
                            ),
                            DropdownMenuItem(
                              value: 'USER',
                              child: Text('Utilisateur'),
                            ),
                            DropdownMenuItem(
                              value: 'PARTNER',
                              child: Text('Partenaire'),
                            ),
                            DropdownMenuItem(
                              value: 'GARE',
                              child: Text('Gare'),
                            ),
                            DropdownMenuItem(
                              value: 'CHAUFFEUR',
                              child: Text('Chauffeur'),
                            ),
                            DropdownMenuItem(
                              value: 'ADMIN',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _roleFilter = v ?? 'TOUS';
                            _pageSize = 20;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: 'Statut',
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
                  usersAsync.when(
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
                            (u) =>
                                u.createdAt != null &&
                                !u.createdAt!.isBefore(_period.fromAsDate) &&
                                !u.createdAt!.isAfter(_period.toAsDate),
                          )
                          .toList();
                      if (_roleFilter != 'TOUS') {
                        filtered = filtered
                            .where((u) => u.roles.contains(_roleFilter))
                            .toList();
                      }
                      if (_statusFilter == 'ACTIF') {
                        filtered = filtered.where((u) => u.enabled).toList();
                      }
                      if (_statusFilter == 'INACTIF') {
                        filtered = filtered.where((u) => !u.enabled).toList();
                      }
                      if (_search.isNotEmpty) {
                        final q = _search.toLowerCase();
                        filtered = filtered
                            .where(
                              (u) =>
                                  u.fullName.toLowerCase().contains(q) ||
                                  (u.email ?? '').toLowerCase().contains(q),
                            )
                            .toList();
                      }

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Aucun utilisateur trouvé',
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
                                '${visible.length} / ${filtered.length} utilisateur(s)',
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
                                        exportUsersCsv(filtered, context),
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
                                        exportUsersPdf(filtered, context),
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
                            (u) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gray200),
                              ),
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserDetailPage(
                                      userId: u.id,
                                      displayName: u.fullName,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: u.enabled
                                              ? AppColors.mobiliBlueFog
                                              : AppColors.gray100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            u.initial,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: u.enabled
                                                  ? AppColors.mobiliBlue
                                                  : AppColors.gray400,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u.fullName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: AppColors.mobiliBlueDeep,
                                              ),
                                            ),
                                            if (u.email != null)
                                              Text(
                                                u.email!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.gray500,
                                                ),
                                              ),
                                            const SizedBox(height: 2),
                                            Wrap(
                                              spacing: 4,
                                              children: u.roles
                                                  .map(
                                                    (r) => Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .mobiliBlue
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        r,
                                                        style: const TextStyle(
                                                          fontSize: 8,
                                                          color: AppColors
                                                              .mobiliBlue,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (u.enabled
                                                          ? AppColors
                                                                .stationGreen
                                                          : AppColors.danger)
                                                      .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              u.enabled ? 'Actif' : 'Inactif',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: u.enabled
                                                    ? AppColors.stationGreen
                                                    : AppColors.danger,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: () => _toggleStatus(u),
                                            child: Icon(
                                              u.enabled
                                                  ? Icons.block_rounded
                                                  : Icons.check_circle_rounded,
                                              color: u.enabled
                                                  ? AppColors.danger
                                                  : AppColors.stationGreen,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.gray300,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
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
