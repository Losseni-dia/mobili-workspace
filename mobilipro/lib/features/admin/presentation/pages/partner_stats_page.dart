import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/features/admin/presentation/pages/admin_gestion_page.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_period_selector.dart';
import 'admin_gestion_page_v2.dart'
    show AdminPartner, adminPartnersProvider, PartnerDetailPage;

class PartnerStatsDetailPage extends ConsumerStatefulWidget {
  const PartnerStatsDetailPage({super.key});
  @override
  ConsumerState<PartnerStatsDetailPage> createState() =>
      _PartnerStatsDetailPageState();
}

class _PartnerStatsDetailPageState
    extends ConsumerState<PartnerStatsDetailPage> {
  AdminStatsPeriod _period = kPeriodMonth;
  String _search = '';
  String _approvalFilter = 'TOUS';
  String _statusFilter = 'TOUS';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve(AdminPartner p) async {
    try {
      await ApiClient.instance.dio.patch('/admin/partners/${p.id}/approve');
      ref.invalidate(adminPartnersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${p.name} approuvé ✅'),
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

  Future<void> _reject(AdminPartner p) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rejeter cette compagnie ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.name} sera rejetée.'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motif du rejet (obligatoire)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: reasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, reasonCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text(
                'Rejeter',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ApiClient.instance.dio.patch(
        '/admin/partners/${p.id}/reject',
        data: {'reason': reason},
      );
      ref.invalidate(adminPartnersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${p.name} rejeté'),
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

  Future<void> _toggle(AdminPartner p) async {
    try {
      await ApiClient.instance.dio.patch('/admin/partners/${p.id}/toggle');
      ref.invalidate(adminPartnersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              p.enabled ? '${p.name} désactivé' : '${p.name} activé',
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
    final async = ref.watch(partnerStatsProvider(_period));
    final partnersAsync = ref.watch(adminPartnersProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Partenaires',
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
                          icon: Icons.add_business_rounded,
                          label: "Aujourd'hui",
                          value: '${stats.todayRegistrations}',
                          color: AppColors.proGold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.business_rounded,
                          label: 'Total',
                          value: '${stats.totalPartners}',
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
                          color: AppColors.proGold,
                          showTooltip: true,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Liste des partenaires',
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
                      hintText: 'Rechercher une compagnie...',
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
                          value: _approvalFilter,
                          decoration: InputDecoration(
                            labelText: 'Approbation',
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
                              child: Text('Toutes'),
                            ),
                            DropdownMenuItem(
                              value: 'PENDING',
                              child: Text('En attente'),
                            ),
                            DropdownMenuItem(
                              value: 'APPROVED',
                              child: Text('Approuvés'),
                            ),
                            DropdownMenuItem(
                              value: 'REJECTED',
                              child: Text('Rejetés'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _approvalFilter = v ?? 'TOUS';
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
                  partnersAsync.when(
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
                      var filtered = all
                          .where((p) => !p.covoiturageSoloPool)
                          .toList();
                      filtered = filtered
                          .where(
                            (p) =>
                                p.createdAt != null &&
                                !p.createdAt!.isBefore(_period.fromAsDate) &&
                                !p.createdAt!.isAfter(_period.toAsDate),
                          )
                          .toList();
                      if (_approvalFilter != 'TOUS') {
                        filtered = filtered
                            .where((p) => p.approvalStatus == _approvalFilter)
                            .toList();
                      }
                      if (_statusFilter == 'ACTIF') {
                        filtered = filtered.where((p) => p.enabled).toList();
                      }
                      if (_statusFilter == 'INACTIF') {
                        filtered = filtered.where((p) => !p.enabled).toList();
                      }
                      if (_search.isNotEmpty) {
                        final q = _search.toLowerCase();
                        filtered = filtered
                            .where(
                              (p) =>
                                  p.name.toLowerCase().contains(q) ||
                                  (p.ownerName ?? '').toLowerCase().contains(q),
                            )
                            .toList();
                      }
                      filtered.sort(
                        (a, b) => a.isPending && !b.isPending
                            ? -1
                            : !a.isPending && b.isPending
                            ? 1
                            : 0,
                      );

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Aucun partenaire trouvé',
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
                                '${visible.length} / ${filtered.length} partenaire(s)',
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
                                        exportPartnersCsv(filtered, context),
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
                                        exportPartnersPdf(filtered, context),
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
                          ...visible.map((p) {
                            final (label, color) = switch (p.approvalStatus) {
                              'PENDING' => ('En attente', AppColors.warning),
                              'REJECTED' => ('Rejeté', AppColors.danger),
                              _ =>
                                p.enabled
                                    ? ('Actif', AppColors.stationGreen)
                                    : ('Inactif', AppColors.danger),
                            };
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PartnerDetailPage(partner: p),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .mobiliBlueDeep,
                                                  ),
                                                ),
                                                if (p.ownerName != null)
                                                  Text(
                                                    p.ownerName!,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.gray500,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                         Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: color,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
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
                                  if (p.isPending)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _reject(p),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'Rejeter',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.danger,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          ElevatedButton.icon(
                                            onPressed: () => _approve(p),
                                            icon: const Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'Approuver',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.stationGreen,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (!p.isPending)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _toggle(p),
                                            icon: Icon(
                                              p.enabled
                                                  ? Icons.pause_circle_rounded
                                                  : Icons.play_circle_rounded,
                                              size: 14,
                                            ),
                                            label: Text(
                                              p.enabled
                                                  ? 'Désactiver'
                                                  : 'Activer',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: p.enabled
                                                  ? AppColors.danger
                                                  : AppColors.stationGreen,
                                              side: BorderSide(
                                                color: p.enabled
                                                    ? AppColors.danger
                                                    : AppColors.stationGreen,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
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
