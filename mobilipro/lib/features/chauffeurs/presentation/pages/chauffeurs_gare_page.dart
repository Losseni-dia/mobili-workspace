import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/search_filter_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────

class ChauffeurDetail {
  const ChauffeurDetail({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.enabled,
    this.email,
    this.phone,
    this.avatarUrl,
    this.affiliationStationId,
    this.affiliationStationName,
  });

  final int id;
  final String firstname;
  final String lastname;
  final bool enabled;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final int? affiliationStationId;
  final String? affiliationStationName;

  String get fullName => '$firstname $lastname';
  String get initials =>
      '${firstname.isNotEmpty ? firstname[0] : ''}${lastname.isNotEmpty ? lastname[0] : ''}'
          .toUpperCase();

  factory ChauffeurDetail.fromJson(Map<String, dynamic> json) =>
      ChauffeurDetail(
        id: json['id'] as int,
        firstname: json['firstname'] as String? ?? '',
        lastname: json['lastname'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        affiliationStationId: json['affiliationStationId'] as int?,
        affiliationStationName: json['affiliationStationName'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final _chauffeursProvider = FutureProvider.autoDispose<List<ChauffeurDetail>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<List<dynamic>>('/partenaire/chauffeurs');
  return (response.data ?? [])
      .map((e) => ChauffeurDetail.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// Constantes filtres
// ─────────────────────────────────────────────────────────────────────────────

const _chauffeurFilterItems = [
  FilterItem(value: 'ACTIFS', label: 'Actifs'),
  FilterItem(value: 'ARCHIVES', label: 'Archivés'),
  FilterItem(value: 'TOUS', label: 'Tous'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class ChauffeursGarePage extends ConsumerStatefulWidget {
  const ChauffeursGarePage({super.key});

  @override
  ConsumerState<ChauffeursGarePage> createState() => _ChauffeursGarePageState();
}

class _ChauffeursGarePageState extends ConsumerState<ChauffeursGarePage> {
  String _filter = 'ACTIFS';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chauffeursAsync = ref.watch(_chauffeursProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Chauffeurs',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_chauffeursProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showChauffeurSheet(context, null),
        backgroundColor: AppColors.mobiliBlue,
        icon: const Icon(Icons.person_add_rounded, color: AppColors.white),
        label: const Text(
          'Nouveau chauffeur',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          SearchFilterBar(
            hintText: 'Rechercher un chauffeur...',
            filterValue: _filter,
            filterItems: _chauffeurFilterItems,
            controller: _searchCtrl,
            onSearchChanged: (v) => setState(() => _search = v),
            onFilterChanged: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: chauffeursAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Erreur : $e',
                      style: const TextStyle(color: AppColors.gray500),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_chauffeursProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (chauffeurs) {
                // Compteurs
                final actifs = chauffeurs.where((c) => c.enabled).length;
                final archives = chauffeurs.where((c) => !c.enabled).length;

                var filtered = chauffeurs.where((c) {
                  if (_filter == 'ACTIFS' && !c.enabled) return false;
                  if (_filter == 'ARCHIVES' && c.enabled) return false;
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    return c.fullName.toLowerCase().contains(q) ||
                        (c.phone ?? '').toLowerCase().contains(q) ||
                        (c.email ?? '').toLowerCase().contains(q);
                  }
                  return true;
                }).toList();

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async => ref.invalidate(_chauffeursProvider),
                  child: CustomScrollView(
                    slivers: [
                      // Stats
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              _StatChip(
                                label: 'Actifs',
                                value: actifs,
                                color: AppColors.stationGreen,
                              ),
                              const SizedBox(width: 10),
                              _StatChip(
                                label: 'Archivés',
                                value: archives,
                                color: AppColors.gray400,
                              ),
                              const SizedBox(width: 10),
                              _StatChip(
                                label: 'Total',
                                value: chauffeurs.length,
                                color: AppColors.mobiliBlue,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          child: Center(
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
                                  child: Icon(
                                    _filter == 'ARCHIVES'
                                        ? Icons.archive_rounded
                                        : Icons.people_rounded,
                                    color: AppColors.mobiliBlue,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _filter == 'ARCHIVES'
                                      ? 'Aucun chauffeur archivé'
                                      : 'Aucun chauffeur actif',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.mobiliBlueDeep,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((ctx, i) {
                              final c = filtered[i];
                              return _ChauffeurCard(
                                chauffeur: c,
                                onEdit: c.enabled
                                    ? () => _showChauffeurSheet(context, c)
                                    : null,
                                onDeactivate: c.enabled
                                    ? () => _confirmDeactivate(context, c)
                                    : null,
                                onReintegrate: !c.enabled
                                    ? () => _reintegrate(context, c)
                                    : null,
                              );
                            }, childCount: filtered.length),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showChauffeurSheet(BuildContext context, ChauffeurDetail? chauffeur) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ChauffeurFormSheet(
        chauffeur: chauffeur,
        onSaved: () {
          ref.invalidate(_chauffeursProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                chauffeur == null
                    ? 'Chauffeur créé avec succès ! ✅'
                    : 'Chauffeur modifié avec succès ! ✅',
              ),
              backgroundColor: AppColors.stationGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, ChauffeurDetail chauffeur) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Désinscrire le chauffeur',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.mobiliBlueDeep,
          ),
        ),
        content: Text(
          '${chauffeur.fullName} sera archivé et ne pourra plus se connecter.\n\nVous pourrez le réintégrer à tout moment depuis l\'onglet "Archivés".',
          style: const TextStyle(color: AppColors.gray500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.gray500),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deactivate(context, chauffeur);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Désinscrire',
              style: TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivate(
    BuildContext context,
    ChauffeurDetail chauffeur,
  ) async {
    try {
      await ApiClient.instance.dio.delete<void>(
        '/partenaire/chauffeurs/${chauffeur.id}',
      );
      ref.invalidate(_chauffeursProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${chauffeur.fullName} archivé — visible dans "Archivés"',
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'archivage'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reintegrate(
    BuildContext context,
    ChauffeurDetail chauffeur,
  ) async {
    try {
      await ApiClient.instance.dio.patch<void>(
        '/partenaire/chauffeurs/${chauffeur.id}/reactivate',
      );
      ref.invalidate(_chauffeursProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${chauffeur.fullName} réintégré avec succès ! ✅'),
            backgroundColor: AppColors.stationGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la réintégration'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte chauffeur
// ─────────────────────────────────────────────────────────────────────────────

class _ChauffeurCard extends StatelessWidget {
  const _ChauffeurCard({
    required this.chauffeur,
    this.onEdit,
    this.onDeactivate,
    this.onReintegrate,
  });
  final ChauffeurDetail chauffeur;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReintegrate;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: chauffeur.enabled ? 1.0 : 0.6,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: chauffeur.enabled ? AppColors.gray200 : AppColors.gray300,
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
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: chauffeur.enabled
                        ? AppColors.mobiliBlue
                        : AppColors.gray300,
                    shape: BoxShape.circle,
                  ),
                  child: chauffeur.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            'http://10.0.2.2:8080/v1/uploads/${chauffeur.avatarUrl}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                chauffeur.initials,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            chauffeur.initials,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chauffeur.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.mobiliBlueDeep,
                              ),
                            ),
                          ),
                          // Badge statut
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: chauffeur.enabled
                                  ? const Color(0xFFD1FAE5)
                                  : AppColors.gray100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  chauffeur.enabled
                                      ? Icons.check_circle_rounded
                                      : Icons.archive_rounded,
                                  size: 10,
                                  color: chauffeur.enabled
                                      ? AppColors.stationGreen
                                      : AppColors.gray500,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  chauffeur.enabled ? 'Actif' : 'Archivé',
                                  style: TextStyle(
                                    color: chauffeur.enabled
                                        ? AppColors.stationGreen
                                        : AppColors.gray500,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (chauffeur.phone != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_rounded,
                              size: 12,
                              color: AppColors.gray400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              chauffeur.phone!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray500,
                              ),
                            ),
                          ],
                        ),
                      if (chauffeur.email != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 12,
                              color: AppColors.gray400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                chauffeur.email!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (chauffeur.affiliationStationName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.store_rounded,
                              size: 12,
                              color: AppColors.mobiliBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              chauffeur.affiliationStationName!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mobiliBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          const Divider(height: 1, color: AppColors.gray100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: chauffeur.enabled
                // Chauffeur actif → Modifier + Désinscrire
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: const Text(
                            'Modifier',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mobiliBlue,
                            side: const BorderSide(color: AppColors.mobiliBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDeactivate,
                          icon: const Icon(Icons.archive_rounded, size: 14),
                          label: const Text(
                            'Désinscrire',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  )
                // Chauffeur archivé → Réintégrer
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onReintegrate,
                      icon: const Icon(
                        Icons.person_add_rounded,
                        size: 16,
                        color: AppColors.white,
                      ),
                      label: const Text(
                        'Réintégrer',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.stationGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet formulaire création / modification
// ─────────────────────────────────────────────────────────────────────────────

class _ChauffeurFormSheet extends StatefulWidget {
  const _ChauffeurFormSheet({required this.onSaved, this.chauffeur});
  final ChauffeurDetail? chauffeur;
  final VoidCallback onSaved;

  @override
  State<_ChauffeurFormSheet> createState() => _ChauffeurFormSheetState();
}

class _ChauffeurFormSheetState extends State<_ChauffeurFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstnameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _loginCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;
  File? _avatarFile;

  bool get _isEdit => widget.chauffeur != null;

  @override
  void initState() {
    super.initState();
    final c = widget.chauffeur;
    _firstnameCtrl = TextEditingController(text: c?.firstname ?? '');
    _lastnameCtrl = TextEditingController(text: c?.lastname ?? '');
    _loginCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _loginCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient.instance.dio;

      final formDataMap = <String, dynamic>{};

      if (_isEdit) {
        // PUT — PartnerChauffeurUpdateRequest (sans login)
        final updateJson = <String, dynamic>{
          'firstname': _firstnameCtrl.text.trim(),
          'lastname': _lastnameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_emailCtrl.text.trim().isNotEmpty)
            'email': _emailCtrl.text.trim(),
          if (_passwordCtrl.text.isNotEmpty) 'password': _passwordCtrl.text,
        };
        formDataMap['chauffeur'] = MultipartFile.fromString(
          jsonEncode(updateJson),
          contentType: DioMediaType('application', 'json'),
        );
      } else {
        // POST — PartnerChauffeurCreateRequest (avec login)
        final createJson = <String, dynamic>{
          'firstname': _firstnameCtrl.text.trim(),
          'lastname': _lastnameCtrl.text.trim(),
          'login': _loginCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_emailCtrl.text.trim().isNotEmpty)
            'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
        };
        formDataMap['chauffeur'] = MultipartFile.fromString(
          jsonEncode(createJson),
          contentType: DioMediaType('application', 'json'),
        );
      }

      if (_avatarFile != null) {
        formDataMap['avatar'] = await MultipartFile.fromFile(
          _avatarFile!.path,
          contentType: DioMediaType('image', 'jpeg'),
        );
      }

      if (_isEdit) {
        await dio.put<void>(
          '/partenaire/chauffeurs/${widget.chauffeur!.id}',
          data: FormData.fromMap(formDataMap),
        );
      } else {
        await dio.post<void>(
          '/partenaire/chauffeurs',
          data: FormData.fromMap(formDataMap),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('—')
            ? e.toString().split('—').last.trim()
            : 'Erreur lors de l\'enregistrement';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEdit
                      ? 'Modifier ${widget.chauffeur!.fullName}'
                      : 'Nouveau chauffeur',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.gray400),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Avatar
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.mobiliBlueFog,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _avatarFile != null
                            ? AppColors.mobiliBlue
                            : AppColors.gray200,
                        width: _avatarFile != null ? 2 : 1,
                      ),
                    ),
                    child: _avatarFile != null
                        ? ClipOval(
                            child: Image.file(_avatarFile!, fit: BoxFit.cover),
                          )
                        : widget.chauffeur?.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              'http://10.0.2.2:8080/v1/uploads/${widget.chauffeur!.avatarUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_rounded,
                                color: AppColors.mobiliBlue,
                                size: 40,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: AppColors.mobiliBlue,
                            size: 40,
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: AppColors.mobiliBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Photo (optionnel)',
              style: TextStyle(fontSize: 11, color: AppColors.gray400),
            ),
          ),
          const SizedBox(height: 16),

          // Prénom + Nom
          Row(
            children: [
              Expanded(
                child: _SheetField(
                  controller: _firstnameCtrl,
                  label: 'Prénom',
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Obligatoire' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetField(
                  controller: _lastnameCtrl,
                  label: 'Nom',
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Obligatoire' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Login (création seulement)
          if (!_isEdit) ...[
            _SheetField(
              controller: _loginCtrl,
              label: 'Identifiant (login)',
              icon: Icons.alternate_email_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
          ],

          // Téléphone
          _SheetField(
            controller: _phoneCtrl,
            label: 'Téléphone *',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obligatoire' : null,
          ),
          const SizedBox(height: 12),

          // Email
          _SheetField(
            controller: _emailCtrl,
            label: 'Email (optionnel)',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          // Mot de passe
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            validator: _isEdit
                ? null
                : (v) {
                    if (v == null || v.isEmpty) return 'Obligatoire';
                    if (v.length < 8) return 'Min 8 caractères';
                    return null;
                  },
            decoration: InputDecoration(
              labelText: _isEdit
                  ? 'Nouveau mot de passe (optionnel)'
                  : 'Mot de passe',
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.gray400,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.gray400,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              filled: true,
              fillColor: AppColors.gray50,
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
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mobiliBlue,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.gray200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isEdit
                          ? 'Enregistrer les modifications'
                          : 'Créer le chauffeur',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget stat chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 20,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget champ formulaire
// ─────────────────────────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.gray400, size: 20),
      filled: true,
      fillColor: AppColors.gray50,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
  );
}
