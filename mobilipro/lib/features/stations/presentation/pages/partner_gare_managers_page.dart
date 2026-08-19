import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import 'gare_detail_page.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════

class StationDetail {
  const StationDetail({
    required this.id,
    required this.name,
    required this.city,
    required this.active,
    required this.responsibleName,
    required this.chauffeurs,
    this.code,
  });
  final int id;
  final String name;
  final String city;
  final bool active;
  final String? responsibleName;
  final List<GareChauffeur> chauffeurs;
  final String? code;
  factory StationDetail.fromJson(Map<String, dynamic> json) => StationDetail(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    active: json['active'] as bool? ?? false,
    responsibleName: json['responsibleName'] as String?,
    code: json['code'] as String?,
    chauffeurs: (json['assignedChauffeurs'] as List<dynamic>? ?? [])
        .map((e) => GareChauffeur.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PartnerChauffeur {
  const PartnerChauffeur({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.enabled,
    this.email,
    this.phone,
    this.affiliationStationId,
    this.affiliationStationName,
  });
  final int id;
  final String firstname;
  final String lastname;
  final bool enabled;
  final String? email;
  final String? phone;
  final int? affiliationStationId;
  final String? affiliationStationName;

  String get fullName => '$firstname $lastname'.trim();
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';
  bool get isAffiliated => affiliationStationId != null;

  factory PartnerChauffeur.fromJson(Map<String, dynamic> json) =>
      PartnerChauffeur(
        id: json['id'] as int,
        firstname: json['firstname'] as String? ?? '',
        lastname: json['lastname'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        affiliationStationId: json['affiliationStationId'] as int?,
        affiliationStationName: json['affiliationStationName'] as String?,
      );
}

class GareUserItem {
  const GareUserItem({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.email,
    required this.phone,
    required this.login,
    required this.enabled,
    this.stationId,
    this.stationName,
  });
  final int id;
  final String firstname;
  final String lastname;
  final String? email;
  final String phone;
  final String login;
  final bool enabled;
  final int? stationId;
  final String? stationName;

  String get fullName => '$firstname $lastname'.trim();
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';

  factory GareUserItem.fromJson(Map<String, dynamic> json) => GareUserItem(
    id: json['id'] as int,
    firstname: json['firstname'] as String? ?? '',
    lastname: json['lastname'] as String? ?? '',
    email: json['email'] as String?,
    phone: json['phone'] as String? ?? '',
    login: json['login'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    stationId: json['stationId'] as int?,
    stationName: json['stationName'] as String?,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS PARTAGÉS
// ═══════════════════════════════════════════════════════════════════════════

final stationsProvider = FutureProvider.autoDispose<List<StationDetail>>((
  ref,
) async {
  final response = await ApiClient.instance.dio.get<List<dynamic>>(
    '/partenaire/stations',
  );
  return (response.data ?? [])
      .map((e) => StationDetail.fromJson(e as Map<String, dynamic>))
      .toList();
});

final chauffeursProvider = FutureProvider.autoDispose<List<PartnerChauffeur>>((
  ref,
) async {
  final response = await ApiClient.instance.dio.get<List<dynamic>>(
    '/partenaire/chauffeurs',
  );
  return (response.data ?? [])
      .map((e) => PartnerChauffeur.fromJson(e as Map<String, dynamic>))
      .toList();
});

final gareUsersProvider = FutureProvider.autoDispose<List<GareUserItem>>((
  ref,
) async {
  final response = await ApiClient.instance.dio.get<List<dynamic>>(
    '/partenaire/gare-users',
  );
  return (response.data ?? [])
      .map((e) => GareUserItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _stationStatsProvider = FutureProvider.autoDispose
    .family<Map<String, double>, int>((ref, stationId) async {
      final response = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/partenaire/dashboard/stats',
        queryParameters: {'stationId': stationId},
      );
      final data = response.data!;
      return {
        'total': (data['totalRevenue'] as num?)?.toDouble() ?? 0,
        'online': (data['revenueOnline'] as num?)?.toDouble() ?? 0,
        'offline': (data['revenueOffline'] as num?)?.toDouble() ?? 0,
        'bookings': (data['totalBookingsCount'] as num?)?.toDouble() ?? 0,
        'trips': (data['activeTripsCount'] as num?)?.toDouble() ?? 0,
      };
    });

void _invalidateAll(WidgetRef ref) {
  ref.invalidate(stationsProvider);
  ref.invalidate(chauffeursProvider);
  ref.invalidate(gareUsersProvider);
}

// ═══════════════════════════════════════════════════════════════════════════
// FILTRES
// ═══════════════════════════════════════════════════════════════════════════

enum PersonFilter { tous, actifs, archives, nonAffilies }

extension PersonFilterLabel on PersonFilter {
  String get label {
    switch (this) {
      case PersonFilter.tous:
        return 'Tous';
      case PersonFilter.actifs:
        return 'Actifs';
      case PersonFilter.archives:
        return 'Archivés';
      case PersonFilter.nonAffilies:
        return 'Non affiliés';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════

class PartnerGareManagersPage extends ConsumerStatefulWidget {
  const PartnerGareManagersPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<PartnerGareManagersPage> createState() =>
      _PartnerGareManagersPageState();
}

class _PartnerGareManagersPageState
    extends ConsumerState<PartnerGareManagersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() => setState(() {}));
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

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => _invalidateAll(ref),
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
          tabs: const [
            Tab(icon: Icon(Icons.store_rounded, size: 20), text: 'Gares'),
            Tab(
              icon: Icon(Icons.directions_car_rounded, size: 20),
              text: 'Chauffeurs',
            ),
            Tab(
              icon: Icon(Icons.badge_rounded, size: 20),
              text: 'Chefs de gare',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          switch (_tabController.index) {
            case 0:
              _showStationFormSheet(context, ref);
              break;
            case 1:
              _showChauffeurFormSheet(context, ref);
              break;
            case 2:
              _showGareUserFormSheet(context, ref);
              break;
          }
        },
        backgroundColor: AppColors.mobiliYellow,
        icon: const Icon(Icons.add_rounded, color: AppColors.mobiliBlueDeep),
        label: Text(
          switch (_tabController.index) {
            0 => 'Nouvelle gare',
            1 => 'Nouveau chauffeur',
            _ => 'Nouveau chef de gare',
          },
          style: const TextStyle(
            color: AppColors.mobiliBlueDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StationsTab(onSnack: _snack),
          _ChauffeursTab(onSnack: _snack),
          _GareUsersTab(onSnack: _snack),
        ],
      ),
    );
  }

  // ── Sheets génériques (accessibles depuis le FAB) ──────────────────────────

  void _showStationFormSheet(
    BuildContext context,
    WidgetRef ref, {
    StationDetail? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StationFormSheet(
        existing: existing,
        onSaved: () => ref.invalidate(stationsProvider),
      ),
    );
  }

  void _showChauffeurFormSheet(
    BuildContext context,
    WidgetRef ref, {
    PartnerChauffeur? existing,
  }) {
    final stations = ref.read(stationsProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChauffeurFormSheet(
        existing: existing,
        stations: stations,
        onSaved: () => ref.invalidate(chauffeursProvider),
      ),
    );
  }

  void _showGareUserFormSheet(
    BuildContext context,
    WidgetRef ref, {
    GareUserItem? existing,
  }) {
    final stations = ref.read(stationsProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GareUserFormSheet(
        existing: existing,
        stations: stations,
        onSaved: () => ref.invalidate(gareUsersProvider),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 1 — GARES
// ═══════════════════════════════════════════════════════════════════════════

class _StationsTab extends ConsumerWidget {
  const _StationsTab({required this.onSnack});
  final void Function(String, {bool error}) onSnack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsProvider);

    return stationsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.mobiliBlue),
      ),
      error: (e, _) => _ErrorRetry(
        message: '$e',
        onRetry: () => ref.invalidate(stationsProvider),
      ),
      data: (stations) {
        if (stations.isEmpty) {
          return const _EmptyState(
            icon: Icons.store_outlined,
            title: 'Aucune gare',
            subtitle: 'Appuyez sur + pour créer une gare',
          );
        }
        return RefreshIndicator(
          color: AppColors.mobiliBlue,
          onRefresh: () async => ref.invalidate(stationsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: stations.length,
            itemBuilder: (_, i) => _StationCard(
              station: stations[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GareDetailPage(
                    stationId: stations[i].id,
                    stationName: stations[i].name,
                    city: stations[i].city,
                    active: stations[i].active,
                    responsibleName: stations[i].responsibleName ?? '',
                    chauffeurs: stations[i].chauffeurs,
                  ),
                ),
              ),
              onEdit: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _StationFormSheet(
                  existing: stations[i],
                  onSaved: () => ref.invalidate(stationsProvider),
                ),
              ),
             onToggle: () => _toggleActive(context, ref, stations[i], onSnack),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    StationDetail s,
    void Function(String, {bool error}) snack,
  ) async {
    try {
      await ApiClient.instance.dio.put(
        '/partenaire/stations/${s.id}',
        data: {'name': s.name, 'city': s.city, 'active': !s.active},
      );
      ref.invalidate(stationsProvider);
      snack(s.active ? '${s.name} désactivée' : '${s.name} activée');
    } catch (e) {
      snack('Erreur : $e', error: true);
    }
  }
}

class _StationCard extends ConsumerWidget {
  const _StationCard({
    required this.station,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
  });
  final StationDetail station;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_stationStatsProvider(station.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
       decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: station.active
                ? AppColors.stationGreen.withValues(alpha: 0.3)
                : AppColors.gray200,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: station.active
                        ? [const Color(0xFF0A1F6E), AppColors.mobiliBlueDeep]
                        : [AppColors.gray400, AppColors.gray500],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            station.city,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                       Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: station.active
                                ? AppColors.stationGreen.withValues(alpha: 0.2)
                                : AppColors.danger.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: station.active
                                  ? AppColors.stationGreen.withValues(
                                      alpha: 0.5,
                                    )
                                  : AppColors.danger.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            station.active ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: station.active
                                  ? AppColors.stationGreen
                                  : AppColors.danger,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (station.code != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            station.code!,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            station.responsibleName?.isNotEmpty == true
                                ? station.responsibleName!
                                : 'Aucun responsable',
                            style: TextStyle(
                              fontSize: 12,
                              color: station.responsibleName?.isNotEmpty == true
                                  ? AppColors.gray600
                                  : AppColors.warning,
                              fontStyle:
                                  station.responsibleName?.isNotEmpty == true
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_car_rounded,
                          size: 14,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${station.chauffeurs.length} chauffeur(s) affilié(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                    statsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(
                          color: AppColors.mobiliBlue,
                          backgroundColor: AppColors.gray100,
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (stats) {
                        if (stats['total'] == 0 && stats['bookings'] == 0) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: AppColors.gray100),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _MiniStat(
                                  icon: Icons.directions_bus_rounded,
                                  label: 'Trajets',
                                  value: '${stats['trips']!.toInt()}',
                                  color: AppColors.mobiliBlue,
                                ),
                                const SizedBox(width: 8),
                                _MiniStat(
                                  icon: Icons.bookmark_rounded,
                                  label: 'Réservations',
                                  value: '${stats['bookings']!.toInt()}',
                                  color: AppColors.stationGreen,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.proGoldSoft,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.proGold.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Revenus',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppColors.proGold,
                                          ),
                                        ),
                                        Text(
                                          '${NumberFormat(
                                                '#,###',
                                              ).format(stats['total'])} F',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.proGold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.wifi_rounded,
                                              size: 9,
                                              color: AppColors.stationGreen,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${NumberFormat(
                                                    '#,###',
                                                  ).format(stats['online'])} F',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors.stationGreen,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.point_of_sale_rounded,
                                              size: 9,
                                              color: AppColors.mobiliYellow,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${NumberFormat(
                                                    '#,###',
                                                  ).format(stats['offline'])} F',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors.mobiliYellow,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.gray100),
                    const SizedBox(height: 10),
                   Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ActionBtn(
                          icon: Icons.open_in_new_rounded,
                          label: 'Détails',
                          color: AppColors.mobiliBlue,
                          onTap: onTap,
                        ),
                        _ActionBtn(
                          icon: Icons.edit_rounded,
                          label: 'Modifier',
                          color: AppColors.mobiliBlue,
                          onTap: onEdit,
                        ),
                        _ActionBtn(
                          icon: station.active
                              ? Icons.pause_circle_rounded
                              : Icons.play_circle_rounded,
                          label: station.active ? 'Désactiver' : 'Activer',
                          color: station.active
                              ? AppColors.warning
                              : AppColors.stationGreen,
                          onTap: onToggle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Formulaire créer/modifier gare
class _StationFormSheet extends StatefulWidget {
  const _StationFormSheet({this.existing, required this.onSaved});
  final StationDetail? existing;
  final VoidCallback onSaved;

  @override
  State<_StationFormSheet> createState() => _StationFormSheetState();
}

class _StationFormSheetState extends State<_StationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _passwordConfirmCtrl;
  bool _active = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _cityCtrl = TextEditingController(text: widget.existing?.city ?? '');
    _passwordCtrl = TextEditingController();
    _passwordConfirmCtrl = TextEditingController();
    _active = widget.existing?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
   final body = {
        'name': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'active': _active,
        if (_passwordCtrl.text.trim().isNotEmpty)
          'password': _passwordCtrl.text.trim(),
      };
      if (widget.existing == null) {
        await ApiClient.instance.dio.post('/partenaire/stations', data: body);
      } else {
        await ApiClient.instance.dio.put(
          '/partenaire/stations/${widget.existing!.id}',
          data: body,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Erreur : $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Handle(),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'Modifier ${widget.existing!.name}' : 'Nouvelle gare',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.mobiliBlueDeep,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _Field(
                controller: _nameCtrl,
                label: 'Nom de la gare',
                icon: Icons.store_rounded,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 12),
            _Field(
                controller: _cityCtrl,
                label: 'Ville',
                icon: Icons.location_city_rounded,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 12),
            const SizedBox(height: 12),
              _Field(
                controller: _passwordCtrl,
                label: isEdit
                    ? 'Nouveau mot de passe gare'
                    : 'Mot de passe de la gare',
                icon: Icons.lock_rounded,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.gray400,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                // StationRequestDTO.password : @Size(min=6) seul, pas @NotBlank — optionnel
                // aussi bien à la création qu'à l'édition (une gare peut être créée sans accès
                // direct, activé plus tard). On ne contraint la longueur que si renseigné.
                validator: (v) => v != null && v.trim().isNotEmpty && v.trim().length < 6
                    ? 'Min 6 caractères'
                    : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _passwordConfirmCtrl,
                label: isEdit
                    ? 'Confirmer le nouveau mot de passe'
                    : 'Confirmer le mot de passe',
                icon: Icons.lock_outline_rounded,
                obscure: _obscureConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.gray400,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (v) {
                  if (_passwordCtrl.text.isEmpty && v == null) return null;
                  if (_passwordCtrl.text.isEmpty && (v == null || v.isEmpty)) {
                    return null;
                  }
                  if (_passwordCtrl.text.isNotEmpty &&
                      v != _passwordCtrl.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliYellow,
                    foregroundColor: AppColors.mobiliBlueDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.mobiliBlueDeep,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit ? 'Enregistrer' : 'Créer la gare',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 2 — CHAUFFEURS
// ═══════════════════════════════════════════════════════════════════════════

class _ChauffeursTab extends ConsumerStatefulWidget {
  const _ChauffeursTab({required this.onSnack});
  final void Function(String, {bool error}) onSnack;

  @override
  ConsumerState<_ChauffeursTab> createState() => _ChauffeursTabState();
}

class _ChauffeursTabState extends ConsumerState<_ChauffeursTab> {
  PersonFilter _filter = PersonFilter.tous;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PartnerChauffeur> _applyFilter(List<PartnerChauffeur> list) {
    var result = list;
    switch (_filter) {
      case PersonFilter.actifs:
        result = result.where((c) => c.enabled).toList();
        break;
      case PersonFilter.archives:
        result = result.where((c) => !c.enabled).toList();
        break;
      case PersonFilter.nonAffilies:
        result = result.where((c) => !c.isAffiliated).toList();
        break;
      case PersonFilter.tous:
        break;
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result
          .where(
            (c) =>
                c.fullName.toLowerCase().contains(q) ||
                (c.phone ?? '').contains(q) ||
                (c.email ?? '').toLowerCase().contains(q) ||
                (c.affiliationStationName ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }

  Future<void> _affilier(PartnerChauffeur c, int? stationId) async {
    try {
      await ApiClient.instance.dio.patch(
        '/partenaire/chauffeurs/${c.id}/affiliation',
        data: {'stationId': stationId},
      );
      ref.invalidate(chauffeursProvider);
      widget.onSnack(
        stationId != null
            ? 'Chauffeur affilié avec succès'
            : 'Affiliation retirée',
      );
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
    }
  }

  Future<void> _toggleArchive(PartnerChauffeur c) async {
    try {
      if (c.enabled) {
        await ApiClient.instance.dio.delete('/partenaire/chauffeurs/${c.id}');
      } else {
        await ApiClient.instance.dio.patch(
          '/partenaire/chauffeurs/${c.id}/reactivate',
        );
      }
      ref.invalidate(chauffeursProvider);
      widget.onSnack(
        c.enabled ? '${c.fullName} archivé' : '${c.fullName} réactivé',
      );
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
    }
  }

  void _showAffiliationDialog(
    PartnerChauffeur c,
    List<StationDetail> stations,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Affecter ${c.fullName}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.mobiliBlueDeep,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choisissez la gare d\'affiliation',
              style: TextStyle(fontSize: 12, color: AppColors.gray400),
            ),
            const SizedBox(height: 16),
            if (c.isAffiliated)
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    color: AppColors.danger,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Retirer l\'affiliation',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Actuellement : ${c.affiliationStationName}',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _affilier(c, null);
                },
              ),
            ...stations.map(
              (s) => ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.affiliationStationId == s.id
                        ? AppColors.stationGreen.withValues(alpha: 0.1)
                        : AppColors.mobiliBlueFog,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: c.affiliationStationId == s.id
                        ? AppColors.stationGreen
                        : AppColors.mobiliBlue,
                    size: 18,
                  ),
                ),
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: c.affiliationStationId == s.id
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.stationGreen,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _affilier(c, s.id);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chauffeursAsync = ref.watch(chauffeursProvider);
    final stationsAsync = ref.watch(stationsProvider);

    return Column(
      children: [
        _SearchAndFilterBar(
          searchCtrl: _searchCtrl,
          onSearchChanged: (v) => setState(() => _search = v),
          filter: _filter,
          onFilterChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: chauffeursAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.mobiliBlue),
            ),
            error: (e, _) => _ErrorRetry(
              message: '$e',
              onRetry: () => ref.invalidate(chauffeursProvider),
            ),
            data: (chauffeurs) {
              final filtered = _applyFilter(chauffeurs);
              if (filtered.isEmpty) {
                return const _EmptyState(
                  icon: Icons.person_off_rounded,
                  title: 'Aucun chauffeur',
                );
              }
              return RefreshIndicator(
                color: AppColors.mobiliBlue,
                onRefresh: () async => ref.invalidate(chauffeursProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ChauffeurCard(
                    chauffeur: filtered[i],
                    onAffilier: () => _showAffiliationDialog(
                      filtered[i],
                      stationsAsync.valueOrNull ?? [],
                    ),
                    onToggleArchive: () => _toggleArchive(filtered[i]),
                    onEdit: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (_) => _ChauffeurFormSheet(
                        existing: filtered[i],
                        stations: stationsAsync.valueOrNull ?? [],
                        onSaved: () => ref.invalidate(chauffeursProvider),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChauffeurCard extends StatelessWidget {
  const _ChauffeurCard({
    required this.chauffeur,
    required this.onAffilier,
    required this.onToggleArchive,
    required this.onEdit,
  });
  final PartnerChauffeur chauffeur;
  final VoidCallback onAffilier;
  final VoidCallback onToggleArchive;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !chauffeur.enabled
              ? AppColors.gray200
              : chauffeur.isAffiliated
              ? AppColors.stationGreen.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
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
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: chauffeur.enabled
                        ? AppColors.mobiliBlueFog
                        : AppColors.gray100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      chauffeur.initial,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: chauffeur.enabled
                            ? AppColors.mobiliBlue
                            : AppColors.gray400,
                        fontSize: 18,
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
                          Text(
                            chauffeur.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: chauffeur.enabled
                                  ? AppColors.mobiliBlueDeep
                                  : AppColors.gray400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: chauffeur.enabled
                                  ? const Color(0xFFD1FAE5)
                                  : AppColors.gray100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              chauffeur.enabled ? 'Actif' : 'Archivé',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: chauffeur.enabled
                                    ? AppColors.stationGreen
                                    : AppColors.gray500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (chauffeur.phone != null)
                        Text(
                          chauffeur.phone!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                      if (chauffeur.email != null)
                        Text(
                          chauffeur.email!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray400,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.gray100),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: chauffeur.isAffiliated
                          ? AppColors.stationGreen.withValues(alpha: 0.1)
                          : AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: chauffeur.isAffiliated
                            ? AppColors.stationGreen.withValues(alpha: 0.3)
                            : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          chauffeur.isAffiliated
                              ? Icons.store_rounded
                              : Icons.store_outlined,
                          size: 13,
                          color: chauffeur.isAffiliated
                              ? AppColors.stationGreen
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            chauffeur.isAffiliated
                                ? chauffeur.affiliationStationName!
                                : 'Non affilié',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: chauffeur.isAffiliated
                                  ? AppColors.stationGreen
                                  : AppColors.warning,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ActionIconBtn(
                  icon: Icons.edit_rounded,
                  color: AppColors.mobiliBlue,
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                if (chauffeur.enabled)
                  _ActionIconBtn(
                    icon: Icons.link_rounded,
                    color: AppColors.proGold,
                    onTap: onAffilier,
                  ),
                if (chauffeur.enabled) const SizedBox(width: 6),
                _ActionIconBtn(
                  icon: chauffeur.enabled
                      ? Icons.archive_rounded
                      : Icons.restore_rounded,
                  color: chauffeur.enabled
                      ? AppColors.danger
                      : AppColors.stationGreen,
                  onTap: onToggleArchive,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Formulaire créer/modifier chauffeur
class _ChauffeurFormSheet extends StatefulWidget {
  const _ChauffeurFormSheet({
    this.existing,
    required this.stations,
    required this.onSaved,
  });
  final PartnerChauffeur? existing;
  final List<StationDetail> stations;
  final VoidCallback onSaved;

  @override
  State<_ChauffeurFormSheet> createState() => _ChauffeurFormSheetState();
}

class _ChauffeurFormSheetState extends State<_ChauffeurFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstnameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _loginCtrl;
  late final TextEditingController _passwordCtrl;
  int? _selectedStationId;
  bool _loading = false;
  String? _error;
  File? _idFront;
  File? _idBack;
  File? _licenseFront;
  File? _licenseBack;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _firstnameCtrl = TextEditingController(text: c?.firstname ?? '');
    _lastnameCtrl = TextEditingController(text: c?.lastname ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _loginCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _selectedStationId = c?.affiliationStationId;
  }

  Future<File?> _pickDoc() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return picked != null ? File(picked.path) : null;
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // CNI + permis obligatoires côté backend uniquement à la création
    // (PartnerChauffeurController.create) — pas exigés à la mise à jour.
    if (widget.existing == null &&
        (_idFront == null ||
            _idBack == null ||
            _licenseFront == null ||
            _licenseBack == null)) {
      setState(() => _error =
          'La carte d\'identité et le permis (recto/verso) sont obligatoires.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.instance.dio;
      if (widget.existing == null) {
        final body = {
          'firstname': _firstnameCtrl.text.trim(),
          'lastname': _lastnameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          'login': _loginCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'stationId': _selectedStationId,
        };
        final formData = FormData.fromMap({
          'chauffeur': MultipartFile.fromString(
            jsonEncode(body),
            contentType: DioMediaType('application', 'json'),
          ),
          'idFront': await MultipartFile.fromFile(_idFront!.path),
          'idBack': await MultipartFile.fromFile(_idBack!.path),
          'licenseFront': await MultipartFile.fromFile(_licenseFront!.path),
          'licenseBack': await MultipartFile.fromFile(_licenseBack!.path),
        });
        await dio.post('/partenaire/chauffeurs', data: formData);
      } else {
        final body = {
          'firstname': _firstnameCtrl.text.trim(),
          'lastname': _lastnameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
        };
        final formData = FormData.fromMap({
          'chauffeur': MultipartFile.fromString(
            jsonEncode(body),
            contentType: DioMediaType('application', 'json'),
          ),
        });
        await dio.put(
          '/partenaire/chauffeurs/${widget.existing!.id}',
          data: formData,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Erreur : $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Handle(),
                const SizedBox(height: 16),
                Text(
                  isEdit
                      ? 'Modifier ${widget.existing!.fullName}'
                      : 'Nouveau chauffeur',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _firstnameCtrl,
                        label: 'Prénom',
                        icon: Icons.person_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obligatoire'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        controller: _lastnameCtrl,
                        label: 'Nom',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obligatoire'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _phoneCtrl,
                  label: 'Téléphone',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  validator: !isEdit
                      ? (v) => v == null || v.trim().length < 8
                            ? 'Min 8 caractères'
                            : null
                      : null,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _emailCtrl,
                  label: 'Email (optionnel)',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 12),
                  _Field(
                    controller: _loginCtrl,
                    label: 'Login',
                    icon: Icons.account_circle_rounded,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _passwordCtrl,
                    label: 'Mot de passe',
                    icon: Icons.lock_rounded,
                    obscure: true,
                    validator: (v) =>
                        v == null || v.length < 8 ? 'Min 8 caractères' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CARTE D\'IDENTITÉ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mobiliBlue,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DocPicker(
                          label: 'Recto',
                          file: _idFront,
                          onPick: () async {
                            final f = await _pickDoc();
                            if (f != null) setState(() => _idFront = f);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DocPicker(
                          label: 'Verso',
                          file: _idBack,
                          onPick: () async {
                            final f = await _pickDoc();
                            if (f != null) setState(() => _idBack = f);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PERMIS DE CONDUIRE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mobiliBlue,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DocPicker(
                          label: 'Recto',
                          file: _licenseFront,
                          onPick: () async {
                            final f = await _pickDoc();
                            if (f != null) setState(() => _licenseFront = f);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DocPicker(
                          label: 'Verso',
                          file: _licenseBack,
                          onPick: () async {
                            final f = await _pickDoc();
                            if (f != null) setState(() => _licenseBack = f);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.stations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _StationDropdown(
                    stations: widget.stations,
                    value: _selectedStationId,
                    onChanged: (v) => setState(() => _selectedStationId = v),
                    hint: 'Gare d\'affiliation (optionnel)',
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mobiliYellow,
                      foregroundColor: AppColors.mobiliBlueDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.mobiliBlueDeep,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isEdit ? 'Enregistrer' : 'Créer le chauffeur',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur photo recto/verso pour les documents chauffeur (CNI, permis) — même pattern que
/// `_PhotoPicker` dans register_carpool_chauffeur_page.dart (auth) et `_DocPicker` dans
/// chauffeurs_gare_page.dart (chauffeurs), dupliqué ici car privé à ce fichier.
class _DocPicker extends StatelessWidget {
  const _DocPicker({required this.label, required this.file, required this.onPick});
  final String label;
  final File? file;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPick,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: file != null ? AppColors.mobiliBlue : AppColors.gray200,
              width: file != null ? 2 : 1,
            ),
          ),
          child: file != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file!, fit: BoxFit.cover, width: double.infinity),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: AppColors.gray300, size: 22),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(color: AppColors.gray400, fontSize: 11)),
                  ],
                ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 3 — CHEFS DE GARE
// ═══════════════════════════════════════════════════════════════════════════

class _GareUsersTab extends ConsumerStatefulWidget {
  const _GareUsersTab({required this.onSnack});
  final void Function(String, {bool error}) onSnack;

  @override
  ConsumerState<_GareUsersTab> createState() => _GareUsersTabState();
}

class _GareUsersTabState extends ConsumerState<_GareUsersTab> {
  PersonFilter _filter = PersonFilter.tous;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GareUserItem> _applyFilter(List<GareUserItem> list) {
    var result = list;
    switch (_filter) {
      case PersonFilter.actifs:
        result = result.where((c) => c.enabled).toList();
        break;
      case PersonFilter.archives:
        result = result.where((c) => !c.enabled).toList();
        break;
      case PersonFilter.nonAffilies:
        result = result.where((c) => c.stationId == null).toList();
        break;
      case PersonFilter.tous:
        break;
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result
          .where(
            (c) =>
                c.fullName.toLowerCase().contains(q) ||
                (c.email ?? '').toLowerCase().contains(q) ||
                c.login.toLowerCase().contains(q) ||
                (c.stationName ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }

  Future<void> _reassign(GareUserItem u, int stationId) async {
    try {
      await ApiClient.instance.dio.patch(
        '/partenaire/gare-users/${u.id}/affiliation',
        data: {'stationId': stationId},
      );
      ref.invalidate(gareUsersProvider);
      ref.invalidate(stationsProvider);
      widget.onSnack('${u.fullName} réaffecté avec succès');
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
    }
  }

  Future<void> _toggleArchive(GareUserItem u) async {
    try {
      if (u.enabled) {
        await ApiClient.instance.dio.delete('/partenaire/gare-users/${u.id}');
      } else {
        await ApiClient.instance.dio.patch(
          '/partenaire/gare-users/${u.id}/reactivate',
        );
      }
      ref.invalidate(gareUsersProvider);
      widget.onSnack(
        u.enabled ? '${u.fullName} archivé' : '${u.fullName} réactivé',
      );
    } catch (e) {
      widget.onSnack('Erreur : $e', error: true);
    }
  }

  void _showReassignDialog(GareUserItem u, List<StationDetail> stations) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réaffecter ${u.fullName}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.mobiliBlueDeep,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choisissez la nouvelle gare',
              style: TextStyle(fontSize: 12, color: AppColors.gray400),
            ),
            const SizedBox(height: 16),
            ...stations.map(
              (s) => ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: u.stationId == s.id
                        ? AppColors.stationGreen.withValues(alpha: 0.1)
                        : AppColors.mobiliBlueFog,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: u.stationId == s.id
                        ? AppColors.stationGreen
                        : AppColors.mobiliBlue,
                    size: 18,
                  ),
                ),
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(s.city, style: const TextStyle(fontSize: 11)),
                trailing: u.stationId == s.id
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.stationGreen,
                      )
                    : null,
                onTap: u.stationId == s.id
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _reassign(u, s.id);
                      },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(gareUsersProvider);
    final stationsAsync = ref.watch(stationsProvider);

    return Column(
      children: [
        _SearchAndFilterBar(
          searchCtrl: _searchCtrl,
          onSearchChanged: (v) => setState(() => _search = v),
          filter: _filter,
          onFilterChanged: (f) => setState(() => _filter = f),
          showNonAffilies: false,
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.mobiliBlue),
            ),
            error: (e, _) => _ErrorRetry(
              message: '$e',
              onRetry: () => ref.invalidate(gareUsersProvider),
            ),
            data: (users) {
              final filtered = _applyFilter(users);
              if (filtered.isEmpty) {
                return const _EmptyState(
                  icon: Icons.badge_outlined,
                  title: 'Aucun chef de gare',
                  subtitle: 'Appuyez sur + pour en créer un',
                );
              }
              return RefreshIndicator(
                color: AppColors.mobiliBlue,
                onRefresh: () async => ref.invalidate(gareUsersProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _GareUserCard(
                    user: filtered[i],
                    onReassign: () => _showReassignDialog(
                      filtered[i],
                      stationsAsync.valueOrNull ?? [],
                    ),
                    onToggleArchive: () => _toggleArchive(filtered[i]),
                    onEdit: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (_) => _GareUserFormSheet(
                        existing: filtered[i],
                        stations: stationsAsync.valueOrNull ?? [],
                        onSaved: () => ref.invalidate(gareUsersProvider),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GareUserCard extends StatelessWidget {
  const _GareUserCard({
    required this.user,
    required this.onReassign,
    required this.onToggleArchive,
    required this.onEdit,
  });
  final GareUserItem user;
  final VoidCallback onReassign;
  final VoidCallback onToggleArchive;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.enabled
              ? AppColors.proGold.withValues(alpha: 0.3)
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: user.enabled
                        ? AppColors.proGoldSoft
                        : AppColors.gray100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.initial,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: user.enabled
                            ? AppColors.proGold
                            : AppColors.gray400,
                        fontSize: 18,
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
                          Flexible(
                            child: Text(
                              user.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: user.enabled
                                    ? AppColors.mobiliBlueDeep
                                    : AppColors.gray400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: user.enabled
                                  ? const Color(0xFFD1FAE5)
                                  : AppColors.gray100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user.enabled ? 'Actif' : 'Archivé',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: user.enabled
                                    ? AppColors.stationGreen
                                    : AppColors.gray500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        user.email ?? '—',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '@${user.login}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.gray400,
                            ),
                          ),
                          if (user.phone.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.phone_rounded,
                              size: 10,
                              color: AppColors.gray400,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              user.phone,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.gray400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.gray100),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mobiliBlueFog,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.mobiliBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.store_rounded,
                          size: 13,
                          color: AppColors.mobiliBlue,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            user.stationName ?? '—',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mobiliBlue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ActionIconBtn(
                  icon: Icons.edit_rounded,
                  color: AppColors.mobiliBlue,
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                if (user.enabled)
                  _ActionIconBtn(
                    icon: Icons.swap_horiz_rounded,
                    color: AppColors.proGold,
                    onTap: onReassign,
                  ),
                if (user.enabled) const SizedBox(width: 6),
                _ActionIconBtn(
                  icon: user.enabled
                      ? Icons.archive_rounded
                      : Icons.restore_rounded,
                  color: user.enabled
                      ? AppColors.danger
                      : AppColors.stationGreen,
                  onTap: onToggleArchive,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Formulaire créer/modifier chef de gare
class _GareUserFormSheet extends StatefulWidget {
  const _GareUserFormSheet({
    this.existing,
    required this.stations,
    required this.onSaved,
  });
  final GareUserItem? existing;
  final List<StationDetail> stations;
  final VoidCallback onSaved;

  @override
  State<_GareUserFormSheet> createState() => _GareUserFormSheetState();
}

class _GareUserFormSheetState extends State<_GareUserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstnameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _loginCtrl;
  late final TextEditingController _passwordCtrl;
  int? _selectedStationId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _firstnameCtrl = TextEditingController(text: u?.firstname ?? '');
    _lastnameCtrl = TextEditingController(text: u?.lastname ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    _loginCtrl = TextEditingController(text: u?.login ?? '');
    _passwordCtrl = TextEditingController();
    _selectedStationId =
        u?.stationId ??
        (widget.stations.isNotEmpty ? widget.stations.first.id : null);
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.instance.dio;
      if (widget.existing == null) {
        await dio.post(
          '/partenaire/stations/gare-accounts',
          data: {
            'stationId': _selectedStationId,
            'firstname': _firstnameCtrl.text.trim(),
            'lastname': _lastnameCtrl.text.trim(),
            'email': _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'login': _loginCtrl.text.trim(),
            'password': _passwordCtrl.text,
          },
        );
      } else {
        await dio.put(
          '/partenaire/gare-users/${widget.existing!.id}',
          data: {
            'firstname': _firstnameCtrl.text.trim(),
            'lastname': _lastnameCtrl.text.trim(),
            'email': _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'password': _passwordCtrl.text.trim().isEmpty
                ? null
                : _passwordCtrl.text.trim(),
          },
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Erreur : $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Handle(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.proGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.badge_rounded,
                        color: AppColors.proGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'Modifier ${widget.existing!.fullName}'
                            : 'Nouveau chef de gare',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.mobiliBlueDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _firstnameCtrl,
                        label: 'Prénom',
                        icon: Icons.person_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obligatoire'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        controller: _lastnameCtrl,
                        label: 'Nom',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obligatoire'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _phoneCtrl,
                  label: 'Téléphone',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  // GareUserCreateRequest.phone : @Size(max = 20) seul, pas de minimum côté
                  // backend — le "min 8" n'était pas justifié, retiré au profit du max 20.
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Obligatoire'
                      : v.trim().length > 20
                          ? 'Max 20 caractères'
                          : null,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _emailCtrl,
                  label: 'Email (optionnel)',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  // Même regex que les autres formulaires (register_page.dart) — l'ancien
                  // contrôle "contains('@')" était trop permissif.
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final emailRx =
                        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$');
                    if (!emailRx.hasMatch(v.trim())) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _loginCtrl,
                  label: 'Login',
                  icon: Icons.account_circle_rounded,
                  // GareUserCreateRequest.login : @Size(min = 2, max = 64).
                  validator: isEdit
                      ? null
                      : (v) {
                          if (v == null || v.trim().isEmpty) return 'Obligatoire';
                          final len = v.trim().length;
                          if (len < 2 || len > 64) return 'Entre 2 et 64 caractères';
                          return null;
                        },
                  enabled: !isEdit,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _passwordCtrl,
                  label: isEdit
                      ? 'Nouveau mot de passe (optionnel)'
                      : 'Mot de passe',
                  icon: Icons.lock_rounded,
                  obscure: true,
                  // GareUserCreateRequest.password : @Size(min = 6, max = 128).
                  validator: isEdit
                      ? null
                      : (v) {
                          if (v == null || v.length < 6) return 'Min 6 caractères';
                          if (v.length > 128) return 'Max 128 caractères';
                          return null;
                        },
                ),
                if (!isEdit && widget.stations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _StationDropdown(
                    stations: widget.stations,
                    value: _selectedStationId,
                    onChanged: (v) => setState(() => _selectedStationId = v),
                    hint: 'Gare d\'affectation',
                    allowNull: false,
                  ),
                ],
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.mobiliBlueFog,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.mobiliBlue,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gare actuelle : ${widget.existing!.stationName ?? '—'}. Utilisez "Réaffecter" pour changer de gare.',
                            style: const TextStyle(
                              color: AppColors.mobiliBlue,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.proGold,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isEdit ? 'Enregistrer' : 'Créer le compte',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS PARTAGÉS
// ═══════════════════════════════════════════════════════════════════════════

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterChanged,
    this.showNonAffilies = true,
  });
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final PersonFilter filter;
  final ValueChanged<PersonFilter> onFilterChanged;
  final bool showNonAffilies;

  @override
  Widget build(BuildContext context) {
    final filters = showNonAffilies
        ? PersonFilter.values
        : PersonFilter.values
              .where((f) => f != PersonFilter.nonAffilies)
              .toList();

    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                hintStyle: const TextStyle(
                  color: AppColors.gray400,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.gray400,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.gray50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                  borderSide: const BorderSide(
                    color: AppColors.mobiliBlue,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => onFilterChanged(f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: filter == f
                                  ? AppColors.mobiliBlue
                                  : AppColors.gray100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              f.label,
                              style: TextStyle(
                                color: filter == f
                                    ? AppColors.white
                                    : AppColors.gray600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.gray100),
        ],
      ),
    );
  }
}

class _StationDropdown extends StatelessWidget {
  const _StationDropdown({
    required this.stations,
    required this.value,
    required this.onChanged,
    required this.hint,
    this.allowNull = true,
  });
  final List<StationDetail> stations;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String hint;
  final bool allowNull;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gray200),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: value,
        isExpanded: true,
        hint: Text(
          hint,
          style: const TextStyle(color: AppColors.gray400, fontSize: 13),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.gray400,
        ),
        items: [
          if (allowNull)
            const DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'Aucune gare',
                style: TextStyle(color: AppColors.gray500),
              ),
            ),
          ...stations.map(
            (s) => DropdownMenuItem<int?>(
              value: s.id,
              child: Text('${s.name} (${s.city})'),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionIconBtn extends StatelessWidget {
  const _ActionIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.suffixIcon,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    obscureText: obscure,
    enabled: enabled,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.gray400, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: enabled ? AppColors.white : AppColors.gray100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.mobiliBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
  );
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.gray300,
        borderRadius: BorderRadius.circular(2),
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
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(color: AppColors.gray400, fontSize: 13),
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
