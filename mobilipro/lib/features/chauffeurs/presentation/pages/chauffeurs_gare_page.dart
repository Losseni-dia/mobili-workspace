import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

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
// Page
// ─────────────────────────────────────────────────────────────────────────────

const _chauffeurFilterItems = [
  FilterItem(value: 'TOUS', label: 'Tous'),
  FilterItem(value: 'ACTIF', label: 'Actif'),
  FilterItem(value: 'INACTIF', label: 'Inactif'),
];

class ChauffeursGarePage extends ConsumerStatefulWidget {
  const ChauffeursGarePage({super.key});

  @override
  ConsumerState<ChauffeursGarePage> createState() => _ChauffeursGarePageState();
}

class _ChauffeursGarePageState extends ConsumerState<ChauffeursGarePage> {
  String _filter = 'TOUS';
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
        onPressed: () => _showCreateDialog(context),
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
                var filtered = chauffeurs.where((c) {
                  if (_filter == 'ACTIF' && !c.enabled) return false;
                  if (_filter == 'INACTIF' && c.enabled) return false;
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    return c.fullName.toLowerCase().contains(q) ||
                        (c.phone ?? '').toLowerCase().contains(q) ||
                        (c.email ?? '').toLowerCase().contains(q);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
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
                          child: const Icon(
                            Icons.people_rounded,
                            color: AppColors.mobiliBlue,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Aucun chauffeur',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.mobiliBlueDeep,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Appuyez sur + pour ajouter un chauffeur',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async => ref.invalidate(_chauffeursProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) =>
                        _ChauffeurCard(chauffeur: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateChauffeurSheet(
        onCreated: () {
          ref.invalidate(_chauffeursProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chauffeur créé avec succès ! ✅'),
              backgroundColor: AppColors.stationGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte chauffeur
// ─────────────────────────────────────────────────────────────────────────────

class _ChauffeurCard extends StatelessWidget {
  const _ChauffeurCard({required this.chauffeur});
  final ChauffeurDetail chauffeur;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gray200),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: chauffeur.enabled ? AppColors.mobiliBlue : AppColors.gray300,
            shape: BoxShape.circle,
          ),
          child: Center(
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
                    child: Text(
                      chauffeur.enabled ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        color: chauffeur.enabled
                            ? AppColors.stationGreen
                            : AppColors.gray500,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (chauffeur.phone != null) ...[
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
              ],
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
                    Text(
                      chauffeur.email!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray500,
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
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet création chauffeur
// ─────────────────────────────────────────────────────────────────────────────

class _CreateChauffeurSheet extends StatefulWidget {
  const _CreateChauffeurSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  State<_CreateChauffeurSheet> createState() => _CreateChauffeurSheetState();
}

class _CreateChauffeurSheetState extends State<_CreateChauffeurSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstnameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient.instance.dio;
      await dio.post<void>(
        '/partenaire/chauffeurs',
        data: {
          'firstname': _firstnameCtrl.text.trim(),
          'lastname': _lastnameCtrl.text.trim(),
          'login': _loginCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_emailCtrl.text.trim().isNotEmpty)
            'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('—')
            ? e.toString().split('—').last.trim()
            : 'Erreur lors de la création';
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
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nouveau chauffeur',
                  style: TextStyle(
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

          // Login
          _SheetField(
            controller: _loginCtrl,
            label: 'Identifiant (login)',
            icon: Icons.alternate_email_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obligatoire' : null,
          ),
          const SizedBox(height: 12),

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

          // Email (optionnel)
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
            validator: (v) {
              if (v == null || v.isEmpty) return 'Obligatoire';
              if (v.length < 8) return 'Min 8 caractères';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Mot de passe',
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

          // Bouton créer
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
                  : const Text(
                      'Créer le chauffeur',
                      style: TextStyle(
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
// Widgets helper
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
