import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/core/services/analytics_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import 'admin_gestion_page_v2.dart'
    show
        AdminPartner,
        AdminUser,
        CovoiturageSoloDriver,
        PartnerDetail,
        UserDetail,
        adminPartnersProvider,
        adminUsersProvider,
        adminCovoiturageDriversProvider,
        partnerDetailProvider,
        userDetailProvider,
        PartnerDetailPage,
        UserDetailPage;

// ═══════════════════════════════════════════════════════════════════════════
// EXPORT CSV
// ═══════════════════════════════════════════════════════════════════════════

Future<void> exportPartnersCsv(
  List<AdminPartner> partners,
  BuildContext context,
) async {
  final rows = [
    [
      'ID',
      'Nom',
      'Propriétaire',
      'Email',
      'Téléphone',
      'N° entreprise',
      'Statut',
      'Approbation',
    ],
    ...partners.map(
      (p) => [
        p.id,
        p.name,
        p.ownerName ?? '',
        p.email ?? '',
        p.phone ?? '',
        p.businessNumber ?? '',
        p.enabled ? 'Actif' : 'Inactif',
        p.approvalStatus,
      ],
    ),
  ];
  await _shareCsv(rows, 'partenaires', context);
  AnalyticsService.logExportCsv(type: 'partenaires');
}

Future<void> exportUsersCsv(List<AdminUser> users, BuildContext context) async {
  final rows = [
    ['ID', 'Prénom', 'Nom', 'Email', 'Rôles', 'Statut', 'Compagnie', 'Gare'],
    ...users.map(
      (u) => [
        u.id,
        u.firstname,
        u.lastname,
        u.email ?? '',
        u.roles.join(' | '),
        u.enabled ? 'Actif' : 'Inactif',
        u.linkedCompanyName ?? '',
        u.stationName ?? '',
      ],
    ),
  ];
  await _shareCsv(rows, 'utilisateurs', context);
   AnalyticsService.logExportCsv(type: 'utilisateurs');
}

Future<void> exportDriversCsv(
  List<CovoiturageSoloDriver> drivers,
  BuildContext context,
) async {
  final rows = [
    ['ID', 'Prénom', 'Nom', 'Email', 'Statut KYC', 'Compte'],
    ...drivers.map(
      (d) => [
        d.id,
        d.firstname,
        d.lastname,
        d.email ?? '',
        d.kycStatus ?? '',
        d.enabled ? 'Actif' : 'Inactif',
      ],
    ),
  ];
  await _shareCsv(rows, 'covoiturage_chauffeurs', context);
   AnalyticsService.logExportCsv(type: 'covoiturage');
}

Future<void> _shareCsv(
  List<List<dynamic>> rows,
  String name,
  BuildContext context,
) async {
  try {
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final filename =
        '${name}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Export Mobili — $name');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur export : $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> exportPartnersPdf(
  List<AdminPartner> partners,
  BuildContext context,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          'Partenaires',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: [
            'Nom',
            'Propriétaire',
            'Email',
            'Téléphone',
            'Statut',
            'Approbation',
          ],
          data: partners
              .map(
                (p) => [
                  p.name,
                  p.ownerName ?? '—',
                  p.email ?? '—',
                  p.phone ?? '—',
                  p.enabled ? 'Actif' : 'Inactif',
                  p.approvalStatus,
                ],
              )
              .toList(),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/partenaires_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  await Share.shareXFiles([
    XFile(file.path),
  ], subject: 'Export Mobili — Partenaires');
  AnalyticsService.logExportCsv(type: 'partenaires_pdf');
}

Future<void> exportUsersPdf(List<AdminUser> users, BuildContext context) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          'Utilisateurs',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Nom', 'Email', 'Rôles', 'Statut', 'Compagnie'],
          data: users
              .map(
                (u) => [
                  u.fullName,
                  u.email ?? '—',
                  u.roles.join(', '),
                  u.enabled ? 'Actif' : 'Inactif',
                  u.linkedCompanyName ?? '—',
                ],
              )
              .toList(),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/utilisateurs_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  await Share.shareXFiles([
    XFile(file.path),
  ], subject: 'Export Mobili — Utilisateurs');
  AnalyticsService.logExportCsv(type: 'utilisateurs_pdf');
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════

class AdminGestionPage extends ConsumerStatefulWidget {
  const AdminGestionPage({super.key});

  @override
  ConsumerState<AdminGestionPage> createState() => _AdminGestionPageState();
}

class _AdminGestionPageState extends ConsumerState<AdminGestionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.stationGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _invalidateAll() {
    ref.invalidate(adminPartnersProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminCovoiturageDriversProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        ref
            .watch(adminPartnersProvider)
            .valueOrNull
            ?.where((p) => p.isPending && !p.covoiturageSoloPool)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Gestion',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _invalidateAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.mobiliYellow,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                backgroundColor: AppColors.danger,
                child: const Icon(Icons.business_rounded, size: 20),
              ),
              text: 'Partenaires',
            ),
            const Tab(
              icon: Icon(Icons.people_rounded, size: 20),
              text: 'Utilisateurs',
            ),
            const Tab(
              icon: Icon(Icons.directions_car_rounded, size: 20),
              text: 'Covoiturage',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PartnersTab(onSnack: _snack),
          _UsersTab(onSnack: _snack),
          _CovoiturageTab(onSnack: _snack),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 1 — PARTENAIRES
// ═══════════════════════════════════════════════════════════════════════════

class _PartnersTab extends ConsumerStatefulWidget {
  const _PartnersTab({required this.onSnack});
  final void Function(String, {bool error}) onSnack;

  @override
  ConsumerState<_PartnersTab> createState() => _PartnersTabState();
}

class _PartnersTabState extends ConsumerState<_PartnersTab> {
  String _search = '';
  String _approvalFilter = 'TOUS';
  String _statusFilter = 'TOUS';
  final _searchCtrl = TextEditingController();
  int _pageSize = 20;
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _fromDate = range.start;
        _toDate = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        _pageSize = 20;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve(AdminPartner p) async {
    try {
      await ApiClient.instance.dio.patch('/admin/partners/${p.id}/approve');
      ref.invalidate(adminPartnersProvider);
      widget.onSnack('${p.name} approuvé ✅');
      AnalyticsService.logApprovePartner(partnerId: p.id);
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
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
                  hintText:
                      'Ex : document illisible, informations incohérentes...',
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
      widget.onSnack('${p.name} rejeté');
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
    }
  }

  Future<void> _toggle(AdminPartner p) async {
    try {
      await ApiClient.instance.dio.patch('/admin/partners/${p.id}/toggle');
      ref.invalidate(adminPartnersProvider);
      widget.onSnack(p.enabled ? '${p.name} désactivé' : '${p.name} activé');
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
    }
  }

List<AdminPartner> _applyFilters(List<AdminPartner> all) {
    var filtered = all.where((p) => !p.covoiturageSoloPool).toList();
    if (_fromDate != null && _toDate != null) {
      filtered = filtered
          .where(
            (p) =>
                p.createdAt != null &&
                !p.createdAt!.isBefore(_fromDate!) &&
                !p.createdAt!.isAfter(_toDate!),
          )
          .toList();
    }
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
                (p.ownerName ?? '').toLowerCase().contains(q) ||
                (p.email ?? '').toLowerCase().contains(q) ||
                (p.phone ?? '').toLowerCase().contains(q) ||
                (p.businessNumber ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    // En attente toujours en tête, puis les autres du plus récent inscrit au plus
    // ancien (au lieu de l'ordre arbitraire renvoyé par le backend) — les partenaires
    // sans date d'inscription (comptes historiques) sont relégués en fin de liste.
    filtered.sort((a, b) {
      if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(adminPartnersProvider);

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: [
              _SearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() {
                  _search = v;
                  _pageSize = 20;
                }),
              ),
              const SizedBox(height: 10),
            Row(
                children: [
                  Expanded(
                    child: _DropdownFilter<String>(
                      label: 'Approbation',
                      value: _approvalFilter,
                      items: const {
                        'TOUS': 'Toutes',
                        'PENDING': 'En attente',
                        'APPROVED': 'Approuvés',
                        'REJECTED': 'Rejetés',
                      },
                      onChanged: (v) => setState(() {
                        _approvalFilter = v;
                        _pageSize = 20;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DropdownFilter<String>(
                      label: 'Statut',
                      value: _statusFilter,
                      items: const {
                        'TOUS': 'Tous',
                        'ACTIF': 'Actifs',
                        'INACTIF': 'Inactifs',
                      },
                      onChanged: (v) => setState(() {
                        _statusFilter = v;
                        _pageSize = 20;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _fromDate != null
                        ? AppColors.mobiliBlueFog
                        : AppColors.gray50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: AppColors.mobiliBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fromDate != null
                            ? '${DateFormat('dd/MM/yy').format(_fromDate!)} → ${DateFormat('dd/MM/yy').format(_toDate!)}'
                            : "Filtrer par date d'inscription",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mobiliBlueDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_fromDate != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() {
                            _fromDate = null;
                            _toDate = null;
                            _pageSize = 20;
                          }),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.gray100),
        Expanded(
          child: partnersAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.mobiliBlue),
            ),
            error: (e, _) => _ErrorRetry(
              message: '$e',
              onRetry: () => ref.invalidate(adminPartnersProvider),
            ),
            data: (all) {
              final scoped = all.where((p) => !p.covoiturageSoloPool).toList();
              final filtered = _applyFilters(all);
              final visible = filtered.take(_pageSize).toList();
              final hasMore = filtered.length > _pageSize;
             final activeFilters = [
                if (_approvalFilter != 'TOUS') _approvalFilter,
                if (_statusFilter != 'TOUS') _statusFilter,
                if (_search.isNotEmpty) '"$_search"',
                if (_fromDate != null) 'date',
              ];

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.business_outlined,
                  title: 'Aucun partenaire',
                  subtitle: activeFilters.isNotEmpty
                      ? 'Filtres actifs : ${activeFilters.join(', ')}'
                      : null,
                );
              }

              return Column(
                children: [
                  // Compteurs — toujours calculés sur l'ensemble des partenaires,
                  // indépendamment des filtres actifs, pour garder une vue d'ensemble.
                  _PartnerCountsBar(
                    pending: scoped.where((p) => p.isPending).length,
                    active: scoped.where((p) => p.enabled).length,
                    inactive: scoped.where((p) => !p.enabled).length,
                  ),
                  // Barre résumé + export
                _ActionBar(
                    count: filtered.length,
                    total: scoped.length,
                    hasFilters: activeFilters.isNotEmpty,
                    onClear: () => setState(() {
                      _approvalFilter = 'TOUS';
                      _statusFilter = 'TOUS';
                      _search = '';
                      _searchCtrl.clear();
                      _fromDate = null;
                      _toDate = null;
                      _pageSize = 20;
                    }),
                    onExportCsv: () => exportPartnersCsv(filtered, context),
                    onExportPdf: () => exportPartnersPdf(filtered, context),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.mobiliBlue,
                      onRefresh: () async =>
                          ref.invalidate(adminPartnersProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: visible.length + (hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == visible.length) {
                            return _LoadMoreButton(
                              remaining: filtered.length - _pageSize,
                              onTap: () => setState(() => _pageSize += 20),
                            );
                          }
                          final p = visible[i];
                          return _PartnerCard(
                            partner: p,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PartnerDetailPage(partner: p),
                              ),
                            ),
                            onApprove: () => _approve(p),
                            onReject: () => _reject(p),
                            onToggle: () => _toggle(p),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 2 — UTILISATEURS
// ═══════════════════════════════════════════════════════════════════════════

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab({required this.onSnack});
  final void Function(String, {bool error}) onSnack;

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  String _search = '';
  String _roleFilter = 'TOUS';
  String _statusFilter = 'TOUS';
  String _companyFilter = 'TOUS';
  final _searchCtrl = TextEditingController();
  int _pageSize = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _fromDate = range.start;
        _toDate = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        _pageSize = 20;
      });
    }
  }

  Future<void> _toggleStatus(AdminUser u) async {
    try {
      await ApiClient.instance.dio.patch(
        '/admin/users/${u.id}/status',
        queryParameters: {'enabled': !u.enabled},
      );
      ref.invalidate(adminUsersProvider);
      widget.onSnack(
        u.enabled ? '${u.fullName} désactivé' : '${u.fullName} activé',
      );
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
    }
  }

  List<AdminUser> _applyFilters(List<AdminUser> all) {
    var filtered = all;
    if (_roleFilter != 'TOUS') {
      filtered = filtered.where((u) => u.roles.contains(_roleFilter)).toList();
    }
    if (_statusFilter == 'ACTIF') {
      filtered = filtered.where((u) => u.enabled).toList();
    }
    if (_statusFilter == 'INACTIF') {
      filtered = filtered.where((u) => !u.enabled).toList();
    }
    if (_companyFilter != 'TOUS') {
      filtered = filtered
          .where((u) => u.linkedCompanyName == _companyFilter)
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered
          .where(
            (u) =>
                u.fullName.toLowerCase().contains(q) ||
                (u.email ?? '').toLowerCase().contains(q) ||
                (u.linkedCompanyName ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);

    return usersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.mobiliBlue),
      ),
      error: (e, _) => _ErrorRetry(
        message: '$e',
        onRetry: () => ref.invalidate(adminUsersProvider),
      ),
      data: (all) {
        final companies =
            all
                .map((u) => u.linkedCompanyName)
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
        final filtered = _applyFilters(all);
        final visible = filtered.take(_pageSize).toList();
        final hasMore = filtered.length > _pageSize;
      final activeFilters = [
          if (_roleFilter != 'TOUS') _roleFilter,
          if (_statusFilter != 'TOUS') _statusFilter,
          if (_companyFilter != 'TOUS') _companyFilter,
          if (_search.isNotEmpty) '"$_search"',
          if (_fromDate != null) 'date',
        ];

        return Column(
          children: [
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  _SearchField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() {
                      _search = v;
                      _pageSize = 20;
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DropdownFilter<String>(
                          label: 'Rôle',
                          value: _roleFilter,
                          items: const {
                            'TOUS': 'Tous les rôles',
                            'USER': 'Utilisateur',
                            'PARTNER': 'Partenaire',
                            'GARE': 'Gare',
                            'CHAUFFEUR': 'Chauffeur',
                            'ADMIN': 'Admin',
                          },
                          onChanged: (v) => setState(() {
                            _roleFilter = v;
                            _pageSize = 20;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DropdownFilter<String>(
                          label: 'Statut',
                          value: _statusFilter,
                          items: const {
                            'TOUS': 'Tous',
                            'ACTIF': 'Actifs',
                            'INACTIF': 'Inactifs',
                          },
                          onChanged: (v) => setState(() {
                            _statusFilter = v;
                            _pageSize = 20;
                          }),
                        ),
                      ),
                    ],
                  ),
                 if (companies.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _DropdownFilter<String>(
                      label: 'Compagnie',
                      value: _companyFilter,
                      items: {
                        'TOUS': 'Toutes les compagnies',
                        for (final c in companies) c: c,
                      },
                      onChanged: (v) => setState(() {
                        _companyFilter = v;
                        _pageSize = 20;
                      }),
                    ),
                  ],
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickDateRange,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _fromDate != null
                            ? AppColors.mobiliBlueFog
                            : AppColors.gray50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: AppColors.mobiliBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _fromDate != null
                                ? '${DateFormat('dd/MM/yy').format(_fromDate!)} → ${DateFormat('dd/MM/yy').format(_toDate!)}'
                                : "Filtrer par date d'inscription",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mobiliBlueDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_fromDate != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() {
                                _fromDate = null;
                                _toDate = null;
                                _pageSize = 20;
                              }),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.gray400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.gray100),
            if (filtered.isEmpty)
              Expanded(
                child: _EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Aucun utilisateur',
                  subtitle: activeFilters.isNotEmpty
                      ? 'Filtres : ${activeFilters.join(', ')}'
                      : null,
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                  _ActionBar(
                      count: filtered.length,
                      total: all.length,
                      hasFilters: activeFilters.isNotEmpty,
                      onClear: () => setState(() {
                        _roleFilter = 'TOUS';
                        _statusFilter = 'TOUS';
                        _companyFilter = 'TOUS';
                        _search = '';
                        _searchCtrl.clear();
                        _fromDate = null;
                        _toDate = null;
                        _pageSize = 20;
                      }),
                      onExportCsv: () => exportUsersCsv(filtered, context),
                      onExportPdf: () => exportUsersPdf(filtered, context),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.mobiliBlue,
                        onRefresh: () async =>
                            ref.invalidate(adminUsersProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: visible.length + (hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == visible.length) {
                              return _LoadMoreButton(
                                remaining: filtered.length - _pageSize,
                                onTap: () => setState(() => _pageSize += 20),
                              );
                            }
                            final u = visible[i];
                            return _UserCard(
                              user: u,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailPage(
                                    userId: u.id,
                                    displayName: u.fullName,
                                  ),
                                ),
                              ),
                              onToggle: () => _toggleStatus(u),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 3 — COVOITURAGE
// ═══════════════════════════════════════════════════════════════════════════

class _CovoiturageTab extends ConsumerStatefulWidget {
  const _CovoiturageTab({required this.onSnack});
  final void Function(String, {bool error}) onSnack;

  @override
  ConsumerState<_CovoiturageTab> createState() => _CovoiturageTabState();
}

class _CovoiturageTabState extends ConsumerState<_CovoiturageTab> {
  String _search = '';
  String _kycFilter = 'TOUS';
  String _statusFilter = 'TOUS';
  final _searchCtrl = TextEditingController();
  int _pageSize = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CovoiturageSoloDriver> _applyFilters(List<CovoiturageSoloDriver> all) {
    var filtered = all;
    if (_kycFilter != 'TOUS') {
      filtered = filtered.where((d) => d.kycStatus == _kycFilter).toList();
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
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(adminCovoiturageDriversProvider);

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: [
              _SearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() {
                  _search = v;
                  _pageSize = 20;
                }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DropdownFilter<String>(
                      label: 'Statut KYC',
                      value: _kycFilter,
                      items: const {
                        'TOUS': 'Tous',
                        'PENDING': 'En attente',
                        'APPROVED': 'Approuvé',
                        'REJECTED': 'Rejeté',
                      },
                      onChanged: (v) => setState(() {
                        _kycFilter = v;
                        _pageSize = 20;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DropdownFilter<String>(
                      label: 'Compte',
                      value: _statusFilter,
                      items: const {
                        'TOUS': 'Tous',
                        'ACTIF': 'Actifs',
                        'INACTIF': 'Inactifs',
                      },
                      onChanged: (v) => setState(() {
                        _statusFilter = v;
                        _pageSize = 20;
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.gray100),
        Expanded(
          child: driversAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.mobiliBlue),
            ),
            error: (e, _) => _ErrorRetry(
              message: '$e',
              onRetry: () => ref.invalidate(adminCovoiturageDriversProvider),
            ),
            data: (all) {
              final filtered = _applyFilters(all);
              final visible = filtered.take(_pageSize).toList();
              final hasMore = filtered.length > _pageSize;
              final activeFilters = [
                if (_kycFilter != 'TOUS') _kycFilter,
                if (_statusFilter != 'TOUS') _statusFilter,
                if (_search.isNotEmpty) '"$_search"',
              ];

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.directions_car_outlined,
                  title: 'Aucun chauffeur',
                  subtitle: activeFilters.isNotEmpty
                      ? 'Filtres : ${activeFilters.join(', ')}'
                      : null,
                );
              }

              return Column(
                children: [
                _ActionBar(
                    count: filtered.length,
                    total: all.length,
                    hasFilters: activeFilters.isNotEmpty,
                    onClear: () => setState(() {
                      _kycFilter = 'TOUS';
                      _statusFilter = 'TOUS';
                      _search = '';
                      _searchCtrl.clear();
                      _pageSize = 20;
                    }),
                    onExportCsv: () => exportDriversCsv(filtered, context),
                    onExportPdf: () => exportDriversCsv(filtered, context),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.mobiliBlue,
                      onRefresh: () async =>
                          ref.invalidate(adminCovoiturageDriversProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: visible.length + (hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == visible.length) {
                            return _LoadMoreButton(
                              remaining: filtered.length - _pageSize,
                              onTap: () => setState(() => _pageSize += 20),
                            );
                          }
                          final d = visible[i];
                          return _CovoiturageCard(
                            driver: d,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserDetailPage(
                                  userId: d.id,
                                  displayName: d.fullName,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTES
// ═══════════════════════════════════════════════════════════════════════════

class _PartnerCountsBar extends StatelessWidget {
  const _PartnerCountsBar({
    required this.pending,
    required this.active,
    required this.inactive,
  });
  final int pending, active, inactive;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Row(
      children: [
        Expanded(
          child: _CountChip(
            label: 'En attente',
            value: pending,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CountChip(
            label: 'Actifs',
            value: active,
            color: AppColors.stationGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CountChip(
            label: 'Inactifs',
            value: inactive,
            color: AppColors.gray500,
          ),
        ),
      ],
    ),
  );
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    ),
  );
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onToggle,
  });
  final AdminPartner partner;
  final VoidCallback onTap, onApprove, onReject, onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: partner.isPending
              ? AppColors.warning.withValues(alpha: 0.4)
              : partner.isRejected
              ? AppColors.danger.withValues(alpha: 0.3)
              : partner.enabled
              ? AppColors.stationGreen.withValues(alpha: 0.3)
              : AppColors.gray200,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: partner.isPending
                        ? AppColors.warningSoft
                        : AppColors.mobiliBlueFog,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    color: partner.isPending
                        ? AppColors.warning
                        : AppColors.mobiliBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              partner.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.mobiliBlueDeep,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _ApprovalBadge(
                            status: partner.approvalStatus,
                            enabled: partner.enabled,
                          ),
                        ],
                      ),
                      if (partner.ownerName != null)
                        Text(
                          partner.ownerName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                      if (partner.email != null)
                        Text(
                          partner.email!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray400,
                          ),
                        ),
                      if (partner.createdAt != null)
                        Text(
                          'Inscrit le ${DateFormat('dd/MM/yyyy').format(partner.createdAt!)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.gray400,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.gray300,
                ),
              ],
            ),
          ),
          if (partner.isPending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppColors.warningSoft,
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Documents à vérifier',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text(
                      'Rejeter',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: const Text(
                      'Approuver',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stationGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!partner.isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      partner.enabled
                          ? Icons.pause_circle_rounded
                          : Icons.play_circle_rounded,
                      size: 14,
                    ),
                    label: Text(
                      partner.enabled ? 'Désactiver' : 'Activer',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: partner.enabled
                          ? AppColors.danger
                          : AppColors.stationGreen,
                      side: BorderSide(
                        color: partner.enabled
                            ? AppColors.danger
                            : AppColors.stationGreen,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onToggle,
  });
  final AdminUser user;
  final VoidCallback onTap, onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: user.enabled
                    ? AppColors.mobiliBlueFog
                    : AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: user.enabled
                        ? AppColors.mobiliBlue
                        : AppColors.gray400,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: user.enabled
                                ? AppColors.mobiliBlueDeep
                                : AppColors.gray400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: user.enabled
                              ? const Color(0xFFD1FAE5)
                              : AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.enabled ? 'Actif' : 'Inactif',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: user.enabled
                                ? AppColors.stationGreen
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (user.email != null)
                    Text(
                      user.email!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: user.roles
                        .map(
                          (r) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mobiliBlue.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.mobiliBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (user.linkedCompanyName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.business_rounded,
                            size: 11,
                            color: AppColors.gray400,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              user.linkedCompanyName!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.gray400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.gray300,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color:
                          (user.enabled
                                  ? AppColors.danger
                                  : AppColors.stationGreen)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (user.enabled
                                    ? AppColors.danger
                                    : AppColors.stationGreen)
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      user.enabled
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      color: user.enabled
                          ? AppColors.danger
                          : AppColors.stationGreen,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _CovoiturageCard extends StatelessWidget {
  const _CovoiturageCard({required this.driver, required this.onTap});
  final CovoiturageSoloDriver driver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (driver.kycStatus) {
      'APPROVED' => ('Approuvé', AppColors.stationGreen),
      'PENDING' => ('En attente', AppColors.warning),
      'REJECTED' => ('Rejeté', AppColors.danger),
      _ => ('—', AppColors.gray400),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    driver.initial,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.mobiliBlueDeep,
                      ),
                    ),
                    if (driver.email != null)
                      Text(
                        driver.email!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gray500,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (driver.enabled
                                        ? AppColors.stationGreen
                                        : AppColors.gray400)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            driver.enabled ? 'Compte actif' : 'Compte inactif',
                            style: TextStyle(
                              fontSize: 10,
                              color: driver.enabled
                                  ? AppColors.stationGreen
                                  : AppColors.gray400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.gray300),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.count,
    required this.total,
    required this.hasFilters,
    required this.onClear,
    required this.onExportCsv,
    required this.onExportPdf,
  });
  final int count;
  final int total;
  final bool hasFilters;
  final VoidCallback onClear;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.mobiliBlueFog,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        const Icon(
          Icons.filter_list_rounded,
          size: 14,
          color: AppColors.mobiliBlue,
        ),
        const SizedBox(width: 6),
        Text(
          '$count / $total',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mobiliBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (hasFilters)
          GestureDetector(
            onTap: onClear,
            child: const Row(
              children: [
                Icon(
                  Icons.clear_rounded,
                  size: 13,
                  color: AppColors.mobiliBlue,
                ),
                SizedBox(width: 3),
                Text(
                  'Effacer',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mobiliBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onExportCsv,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mobiliBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.table_chart_rounded, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'CSV',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onExportPdf,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.proGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  'PDF',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.remaining, required this.onTap});
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.expand_more_rounded, size: 18),
      label: Text('Charger 20 de plus ($remaining restants)'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mobiliBlue,
        side: const BorderSide(color: AppColors.mobiliBlue),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.status, required this.enabled});
  final String status;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'PENDING' => ('En attente', AppColors.warning),
      'REJECTED' => ('Rejeté', AppColors.danger),
      _ =>
        enabled
            ? ('Actif', AppColors.stationGreen)
            : ('Inactif', AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.gray500,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.gray400,
              size: 18,
            ),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mobiliBlueDeep,
              fontWeight: FontWeight.w600,
            ),
            items: items.entries
                .map(
                  (e) => DropdownMenuItem<T>(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => onChanged(v as T),
          ),
        ),
      ),
    ],
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: 'Rechercher...',
      hintStyle: const TextStyle(color: AppColors.gray400, fontSize: 13),
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.gray400,
        size: 20,
      ),
      suffixIcon: controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(
                Icons.clear_rounded,
                size: 16,
                color: AppColors.gray400,
              ),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            )
          : null,
      filled: true,
      fillColor: AppColors.gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.mobiliBlue, width: 2),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.mobiliBlueFog,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: AppColors.mobiliBlue, size: 36),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.mobiliBlueDeep,
            fontSize: 16,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle!,
              style: const TextStyle(color: AppColors.gray400, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    ),
  );
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.danger,
          size: 48,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Erreur : $message',
            style: const TextStyle(color: AppColors.gray500),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    ),
  );
}
