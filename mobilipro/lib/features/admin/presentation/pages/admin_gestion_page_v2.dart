import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/core/services/analytics_service.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════

class AdminPartner {
  const AdminPartner({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.businessNumber,
    required this.enabled,
    this.ownerName,
    this.logoUrl,
    this.kycFrontUrl,
    this.kycBackUrl,
    this.rejectionReason,
    required this.covoiturageSoloPool,
    required this.approvalStatus,
    this.createdAt,
  });
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? businessNumber;
  final bool enabled;
  final String? ownerName;
  final String? logoUrl;
  final String? kycFrontUrl;
  final String? kycBackUrl;
  final String? rejectionReason;
  final bool covoiturageSoloPool;
  final String approvalStatus;
  final DateTime? createdAt;

  bool get isPending => approvalStatus == 'PENDING';
  bool get isApproved => approvalStatus == 'APPROVED';
  bool get isRejected => approvalStatus == 'REJECTED';

  factory AdminPartner.fromJson(Map<String, dynamic> json) => AdminPartner(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    businessNumber: json['businessNumber'] as String?,
    enabled: json['enabled'] as bool? ?? false,
    ownerName: json['ownerName'] as String?,
    logoUrl: json['logoUrl'] as String?,
    kycFrontUrl: json['kycFrontUrl'] as String?,
    kycBackUrl: json['kycBackUrl'] as String?,
    rejectionReason: json['rejectionReason'] as String?,
    covoiturageSoloPool: json['covoiturageSoloPool'] as bool? ?? false,
    approvalStatus: json['approvalStatus'] as String? ?? 'APPROVED',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.email,
    required this.roles,
    required this.enabled,
    this.partnerName,
    this.covoiturageSoloProfile,
    this.linkedCompanyName,
    this.stationName,
    this.employerPartnerId,
    this.createdAt,
  });
  final int id;
  final String firstname;
  final String lastname;
  final String? email;
  final List<String> roles;
  final bool enabled;
  final String? partnerName;
  final bool? covoiturageSoloProfile;
  final String? linkedCompanyName;
  final String? stationName;
  final int? employerPartnerId;
  final DateTime? createdAt;

  String get fullName => '$firstname $lastname'.trim();
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';

factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] as int,
    firstname: json['firstname'] as String? ?? '',
    lastname: json['lastname'] as String? ?? '',
    email: json['email'] as String?,
    roles: (json['roles'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    enabled: json['enabled'] as bool? ?? false,
    partnerName: json['partnerName'] as String?,
    covoiturageSoloProfile: json['covoiturageSoloProfile'] as bool?,
    linkedCompanyName: json['linkedCompanyName'] as String?,
    stationName: json['stationName'] as String?,
    employerPartnerId: json['employerPartnerId'] as int?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}
class CovoiturageSoloDriver {
  const CovoiturageSoloDriver({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.email,
    this.kycStatus,
    required this.enabled,
    this.driverPhotoUrl,
    this.createdAt,
  });
  final int id;
  final String firstname;
  final String lastname;
  final String? email;
  final String? kycStatus;
  final bool enabled;
  final String? driverPhotoUrl;
  final DateTime? createdAt;

  String get fullName => '$firstname $lastname'.trim();
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';

  factory CovoiturageSoloDriver.fromJson(Map<String, dynamic> json) =>
      CovoiturageSoloDriver(
        id: json['id'] as int,
        firstname: json['firstname'] as String? ?? '',
        lastname: json['lastname'] as String? ?? '',
        email: json['email'] as String?,
        kycStatus: json['covoiturageKycStatus'] as String?,
        enabled: json['enabled'] as bool? ?? false,
        driverPhotoUrl: json['covoiturageDriverPhotoUrl'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}

class PartnerDetail {
  const PartnerDetail({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.logoUrl,
    this.businessNumber,
    required this.enabled,
    this.registrationCode,
  });
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? logoUrl;
  final String? businessNumber;
  final bool enabled;
  final String? registrationCode;

  factory PartnerDetail.fromJson(Map<String, dynamic> json) => PartnerDetail(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    logoUrl: json['logoUrl'] as String?,
    businessNumber: json['businessNumber'] as String?,
    enabled: json['enabled'] as bool? ?? false,
    registrationCode: json['registrationCode'] as String?,
  );
}

class UserDetail {
  const UserDetail({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.login,
    this.email,
    this.phone,
    required this.enabled,
    this.balance,
    required this.roles,
    this.stationName,
    this.covoiturageKycStatus,
    this.covoiturageVehicleBrand,
    this.covoiturageVehiclePlate,
    this.covoiturageVehicleColor,
    this.covoiturageDriverPhotoUrl,
    this.covoiturageVehiclePhotoUrl,
    this.covoiturageIdFrontUrl,
    this.covoiturageIdBackUrl,
    this.totalBookingsCount,
  });
  final int id;
  final String firstname;
  final String lastname;
  final String? login;
  final String? email;
  final String? phone;
  final bool enabled;
  final double? balance;
  final List<String> roles;
  final String? stationName;
  final String? covoiturageKycStatus;
  final String? covoiturageVehicleBrand;
  final String? covoiturageVehiclePlate;
  final String? covoiturageVehicleColor;
  final String? covoiturageDriverPhotoUrl;
  final String? covoiturageVehiclePhotoUrl;
  final String? covoiturageIdFrontUrl;
  final String? covoiturageIdBackUrl;
  final int? totalBookingsCount;
  String get fullName => '$firstname $lastname'.trim();
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';
  factory UserDetail.fromJson(Map<String, dynamic> json) => UserDetail(
    id: json['id'] as int,
    firstname: json['firstname'] as String? ?? '',
    lastname: json['lastname'] as String? ?? '',
    login: json['login'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    enabled: json['enabled'] as bool? ?? false,
    balance: (json['balance'] as num?)?.toDouble(),
    roles: (json['roles'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    stationName: json['stationName'] as String?,
    covoiturageKycStatus: json['covoiturageKycStatus'] as String?,
    covoiturageVehicleBrand: json['covoiturageVehicleBrand'] as String?,
    covoiturageVehiclePlate: json['covoiturageVehiclePlate'] as String?,
    covoiturageVehicleColor: json['covoiturageVehicleColor'] as String?,
    covoiturageDriverPhotoUrl: json['covoiturageDriverPhotoUrl'] as String?,
    covoiturageVehiclePhotoUrl: json['covoiturageVehiclePhotoUrl'] as String?,
    covoiturageIdFrontUrl: json['covoiturageIdFrontUrl'] as String?,
    covoiturageIdBackUrl: json['covoiturageIdBackUrl'] as String?,
    totalBookingsCount: json['totalBookingsCount'] as int?,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final adminPartnersProvider = FutureProvider.autoDispose<List<AdminPartner>>((
  ref,
) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>(
    '/admin/partners',
  );
  return (res.data ?? [])
      .map((e) => AdminPartner.fromJson(e as Map<String, dynamic>))
      .toList();
});

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>((
  ref,
) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>('/admin/users');
  return (res.data ?? [])
      .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
      .toList();
});

final adminCovoiturageDriversProvider =
    FutureProvider.autoDispose<List<CovoiturageSoloDriver>>((ref) async {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin/covoiturage-solo-drivers',
      );
      return (res.data ?? [])
          .map((e) => CovoiturageSoloDriver.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final partnerDetailProvider = FutureProvider.autoDispose
    .family<PartnerDetail, int>((ref, id) async {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/partners/$id',
      );
      return PartnerDetail.fromJson(res.data!);
    });

final userDetailProvider = FutureProvider.autoDispose.family<UserDetail, int>((
  ref,
  id,
) async {
  final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
    '/auth/$id',
  );
  return UserDetail.fromJson(res.data!);
});

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
// ONGLET 1 — PARTENAIRES (filtres combinés : recherche + approbation + statut)
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
  String _statusFilter = 'TOUS'; // TOUS / ACTIF / INACTIF
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
      widget.onSnack('${p.name} approuvé ✅');
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
              // Recherche
              _SearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),
              // Filtres combinés en dropdowns
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
                      onChanged: (v) => setState(() => _approvalFilter = v),
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
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ),
                ],
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
            data: (partners) {
              var filtered = partners
                  .where((p) => !p.covoiturageSoloPool)
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
                          (p.ownerName ?? '').toLowerCase().contains(q) ||
                          (p.email ?? '').toLowerCase().contains(q),
                    )
                    .toList();
              }
              // Pending en premier
              filtered.sort(
                (a, b) => a.isPending && !b.isPending
                    ? -1
                    : !a.isPending && b.isPending
                    ? 1
                    : 0,
              );

              // Résumé filtres actifs
              final activeFilters = [
                if (_approvalFilter != 'TOUS') _approvalFilter,
                if (_statusFilter != 'TOUS') _statusFilter,
                if (_search.isNotEmpty) '"$_search"',
              ];

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.business_outlined,
                  title: 'Aucun partenaire',
                  subtitle: activeFilters.isNotEmpty
                      ? 'Filtres : ${activeFilters.join(', ')}'
                      : null,
                );
              }

              return RefreshIndicator(
                color: AppColors.mobiliBlue,
                onRefresh: () async => ref.invalidate(adminPartnersProvider),
                child: Column(
                  children: [
                    if (activeFilters.isNotEmpty)
                      _FilterSummaryBar(
                        count: filtered.length,
                        total: partners
                            .where((p) => !p.covoiturageSoloPool)
                            .length,
                        onClear: () => setState(() {
                          _approvalFilter = 'TOUS';
                          _statusFilter = 'TOUS';
                          _search = '';
                          _searchCtrl.clear();
                        }),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _PartnerCard(
                          partner: filtered[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PartnerDetailPage(partner: filtered[i]),
                            ),
                          ),
                          onApprove: () => _approve(filtered[i]),
                          onReject: () => _reject(filtered[i]),
                          onToggle: () => _toggle(filtered[i]),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 2 — UTILISATEURS (filtres combinés : rôle + statut + compagnie)
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
      widget.onSnack(
        u.enabled ? '${u.fullName} désactivé' : '${u.fullName} activé',
      );
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
    }
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
      data: (users) {
        // Construire la liste des compagnies uniques
        final companies =
            users
                .map((u) => u.linkedCompanyName)
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();

        // Appliquer les filtres
        var filtered = users;
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

        final activeFilters = [
          if (_roleFilter != 'TOUS') _roleFilter,
          if (_statusFilter != 'TOUS') _statusFilter,
          if (_companyFilter != 'TOUS') _companyFilter,
          if (_search.isNotEmpty) '"$_search"',
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
                    onChanged: (v) => setState(() => _search = v),
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
                          onChanged: (v) => setState(() => _roleFilter = v),
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
                          onChanged: (v) => setState(() => _statusFilter = v),
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
                      onChanged: (v) => setState(() => _companyFilter = v),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.gray100),
            if (activeFilters.isNotEmpty)
              _FilterSummaryBar(
                count: filtered.length,
                total: users.length,
                onClear: () => setState(() {
                  _roleFilter = 'TOUS';
                  _statusFilter = 'TOUS';
                  _companyFilter = 'TOUS';
                  _search = '';
                  _searchCtrl.clear();
                }),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Aucun utilisateur',
                      subtitle: activeFilters.isNotEmpty
                          ? 'Filtres : ${activeFilters.join(', ')}'
                          : null,
                    )
                  : RefreshIndicator(
                      color: AppColors.mobiliBlue,
                      onRefresh: () async => ref.invalidate(adminUsersProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _UserCard(
                          user: filtered[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserDetailPage(
                                userId: filtered[i].id,
                                displayName: filtered[i].fullName,
                              ),
                            ),
                          ),
                          onToggle: () => _toggleStatus(filtered[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 3 — COVOITURAGE (filtres : kyc + statut compte)
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                onChanged: (v) => setState(() => _search = v),
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
                      onChanged: (v) => setState(() => _kycFilter = v),
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
                      onChanged: (v) => setState(() => _statusFilter = v),
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
            data: (drivers) {
              var filtered = drivers;
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

              return RefreshIndicator(
                color: AppColors.mobiliBlue,
                onRefresh: () async =>
                    ref.invalidate(adminCovoiturageDriversProvider),
                child: Column(
                  children: [
                    if (activeFilters.isNotEmpty)
                      _FilterSummaryBar(
                        count: filtered.length,
                        total: drivers.length,
                        onClear: () => setState(() {
                          _kycFilter = 'TOUS';
                          _statusFilter = 'TOUS';
                          _search = '';
                          _searchCtrl.clear();
                        }),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _CovoiturageCard(
                          driver: filtered[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserDetailPage(
                                userId: filtered[i].id,
                                displayName: filtered[i].fullName,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onToggle,
  });
  final AdminPartner partner;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onToggle,
  });
  final AdminUser user;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
// PAGES DÉTAIL
// ═══════════════════════════════════════════════════════════════════════════

class PartnerDetailPage extends ConsumerWidget {
  const PartnerDetailPage({super.key, required this.partner});
  final AdminPartner partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(partnerDetailProvider(partner.id));
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Text(
          partner.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erreur : $e',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (detail) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  if (partner.ownerName != null)
                    Text(
                      partner.ownerName!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 8),
                  _ApprovalBadge(
                    status: partner.approvalStatus,
                    enabled: partner.enabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (partner.logoUrl != null ||
                partner.kycFrontUrl != null ||
                partner.kycBackUrl != null)
              _DetailSection(
                title: 'Documents',
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (partner.logoUrl != null)
                        _DocumentThumb(label: 'Logo', path: partner.logoUrl!),
                      if (partner.kycFrontUrl != null)
                        _DocumentThumb(
                          label: 'CNI recto',
                          path: partner.kycFrontUrl!,
                        ),
                      if (partner.kycBackUrl != null)
                        _DocumentThumb(
                          label: 'CNI verso',
                          path: partner.kycBackUrl!,
                        ),
                    ],
                  ),
                ],
              ),
            if (partner.isRejected && partner.rejectionReason != null) ...[
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Motif du rejet',
                children: [
                  Text(
                    partner.rejectionReason!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Informations',
              children: [
                _DetailRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: detail.email ?? '—',
                ),
                _DetailRow(
                  icon: Icons.phone_rounded,
                  label: 'Téléphone',
                  value: detail.phone ?? '—',
                ),
                _DetailRow(
                  icon: Icons.numbers_rounded,
                  label: "Numéro d'entreprise",
                  value: detail.businessNumber ?? '—',
                ),
                _DetailRow(
                  icon: Icons.qr_code_rounded,
                  label: "Code d'inscription",
                  value: detail.registrationCode ?? '—',
                ),
                _DetailRow(
                  icon: detail.enabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  label: 'Statut',
                  value: detail.enabled ? 'Actif' : 'Inactif',
                  valueColor: detail.enabled
                      ? AppColors.stationGreen
                      : AppColors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  const _DocumentThumb({required this.label, required this.path});
  final String label;
  final String path;

  String get _fullUrl {
    // Le backend renvoie un chemin relatif (ex: "partners/kyc/xxx.jpg") ; ces
    // fichiers sont exposés sous /v1/uploads/**.
    const apiBase = 'https://api.my-mobili.com/v1/uploads';
    return path.startsWith('http') ? path : '$apiBase/$path';
  }

  @override
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                _fullUrl,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            _fullUrl,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 90,
              height: 90,
              color: AppColors.gray100,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.gray300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.gray500),
        ),
      ],
    ),
  );
}

class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({
    super.key,
    required this.userId,
    required this.displayName,
  });
  final int userId;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(userDetailProvider(userId));
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Text(
          displayName.isNotEmpty ? displayName : 'Utilisateur',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erreur : $e',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (detail) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        detail.initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  if (detail.login != null)
                    Text(
                      '@${detail.login}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: detail.roles
                        .map(
                          (r) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              r,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Coordonnées',
              children: [
                _DetailRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: detail.email ?? '—',
                ),
                _DetailRow(
                  icon: Icons.phone_rounded,
                  label: 'Téléphone',
                  value: detail.phone ?? '—',
                ),
                _DetailRow(
                  icon: Icons.account_circle_rounded,
                  label: 'Login',
                  value: detail.login ?? '—',
                ),
                _DetailRow(
                  icon: detail.enabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  label: 'Compte',
                  value: detail.enabled ? 'Actif' : 'Désactivé',
                  valueColor: detail.enabled
                      ? AppColors.stationGreen
                      : AppColors.danger,
                ),
              ],
            ),
            if (detail.balance != null ||
                detail.stationName != null ||
                detail.totalBookingsCount != null) ...[
              const SizedBox(height: 12),
              _DetailSection(
                title: 'Activité',
                children: [
                  if (detail.balance != null)
                    _DetailRow(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Solde',
                      value: '${detail.balance!.toStringAsFixed(0)} FCFA',
                    ),
                  if (detail.totalBookingsCount != null)
                    _DetailRow(
                      icon: Icons.bookmark_rounded,
                      label: 'Réservations',
                      value: '${detail.totalBookingsCount}',
                    ),
                  if (detail.stationName != null)
                    _DetailRow(
                      icon: Icons.store_rounded,
                      label: 'Gare',
                      value: detail.stationName!,
                    ),
                ],
              ),
            ],
            if (detail.covoiturageKycStatus != null &&
                detail.covoiturageKycStatus != 'NONE') ...[
              const SizedBox(height: 12),
              _DetailSection(
                title: 'Profil covoiturage',
                children: [
                  _DetailRow(
                    icon: Icons.verified_user_rounded,
                    label: 'Statut KYC',
                    value: switch (detail.covoiturageKycStatus) {
                      'APPROVED' => 'Approuvé',
                      'PENDING' => 'En attente',
                      'REJECTED' => 'Rejeté',
                      'EXPIRED' => 'Expiré',
                      _ => detail.covoiturageKycStatus!,
                    },
                    valueColor: switch (detail.covoiturageKycStatus) {
                      'APPROVED' => AppColors.stationGreen,
                      'PENDING' => AppColors.warning,
                      'REJECTED' || 'EXPIRED' => AppColors.danger,
                      _ => AppColors.gray500,
                    },
                  ),
                  if (detail.covoiturageVehicleBrand != null)
                    _DetailRow(
                      icon: Icons.directions_car_rounded,
                      label: 'Véhicule',
                      value: detail.covoiturageVehicleBrand!,
                    ),
                  if (detail.covoiturageVehiclePlate != null)
                    _DetailRow(
                      icon: Icons.confirmation_number_rounded,
                      label: 'Plaque',
                      value: detail.covoiturageVehiclePlate!,
                    ),
                if (detail.covoiturageVehicleColor != null)
                    _DetailRow(
                      icon: Icons.palette_rounded,
                      label: 'Couleur',
                      value: detail.covoiturageVehicleColor!,
                    ),
                ],
              ),
              if (detail.covoiturageIdFrontUrl != null ||
                  detail.covoiturageIdBackUrl != null ||
                  detail.covoiturageDriverPhotoUrl != null ||
                  detail.covoiturageVehiclePhotoUrl != null) ...[
                const SizedBox(height: 12),
                _DetailSection(
                  title: 'Documents KYC',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (detail.covoiturageIdFrontUrl != null)
                            _DocumentThumb(
                              label: 'CNI recto',
                              path: detail.covoiturageIdFrontUrl!,
                            ),
                          if (detail.covoiturageIdBackUrl != null)
                            _DocumentThumb(
                              label: 'CNI verso',
                              path: detail.covoiturageIdBackUrl!,
                            ),
                          if (detail.covoiturageDriverPhotoUrl != null)
                            _DocumentThumb(
                              label: 'Photo conducteur',
                              path: detail.covoiturageDriverPhotoUrl!,
                            ),
                          if (detail.covoiturageVehiclePhotoUrl != null)
                            _DocumentThumb(
                              label: 'Photo véhicule',
                              path: detail.covoiturageVehiclePhotoUrl!,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              // Boutons KYC — uniquement si PENDING ou EXPIRED
              if (detail.covoiturageKycStatus == 'PENDING' ||
                  detail.covoiturageKycStatus == 'EXPIRED') ...[
                const SizedBox(height: 12),
                _KycActionButtons(userId: detail.id),
              ],
              if (detail.covoiturageKycStatus == 'APPROVED') ...[
                const SizedBox(height: 12),
                _KycActionButtons(userId: detail.id, showRejectOnly: true),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════

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

class _FilterSummaryBar extends StatelessWidget {
  const _FilterSummaryBar({
    required this.count,
    required this.total,
    required this.onClear,
  });
  final int count;
  final int total;
  final VoidCallback onClear;

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
          '$count / $total résultat(s)',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mobiliBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onClear,
          child: const Row(
            children: [
              Icon(Icons.clear_rounded, size: 14, color: AppColors.mobiliBlue),
              SizedBox(width: 4),
              Text(
                'Effacer filtres',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mobiliBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gray200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.mobiliBlueDeep,
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.gray100),
        ...children,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gray400),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.gray500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.mobiliBlueDeep,
          ),
        ),
      ],
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

class _KycActionButtons extends ConsumerWidget {
  const _KycActionButtons({required this.userId, this.showRejectOnly = false});
  final int userId;
  final bool showRejectOnly;

  Future<void> _updateKyc(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    try {
      await ApiClient.instance.dio.patch(
        '/admin/users/$userId/covoiturage-kyc',
        queryParameters: {'status': status},
      );
      ref.invalidate(userDetailProvider(userId));
      ref.invalidate(adminCovoiturageDriversProvider);
      if (status == 'APPROVED') AnalyticsService.logApproveKyc(userId: userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut KYC mis à jour : $status'),
            backgroundColor: status == 'APPROVED'
                ? AppColors.stationGreen
                : AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Décision KYC',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.mobiliBlueDeep,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!showRejectOnly) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateKyc(context, ref, 'APPROVED'),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text(
                      'Approuver',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stationGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateKyc(context, ref, 'REJECTED'),
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text('Rejeter', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
