import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/partner_service.dart';
import '../../domain/models/partner_profile_dto.dart';
import '../../providers/auth_provider.dart';

class PartnerResubmitPage extends ConsumerStatefulWidget {
  const PartnerResubmitPage({super.key});

  @override
  ConsumerState<PartnerResubmitPage> createState() =>
      _PartnerResubmitPageState();
}

class _PartnerResubmitPageState extends ConsumerState<PartnerResubmitPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessNumberCtrl = TextEditingController();

  PartnerProfileDto? _current;
  File? _logo;
  File? _kycFront;
  File? _kycBack;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final company = await PartnerService().getMyCompany();
      _nameCtrl.text = company.name;
      _emailCtrl.text = company.email ?? '';
      _phoneCtrl.text = company.phone ?? '';
      _businessNumberCtrl.text = company.businessNumber ?? '';
      setState(() {
        _current = company;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement : $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _businessNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _logo = File(picked.path));
  }

  Future<void> _pickKycFront() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _kycFront = File(picked.path));
  }

  Future<void> _pickKycBack() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _kycBack = File(picked.path));
  }

  String? _required(String? v, String field) =>
      v == null || v.trim().isEmpty ? '$field requis(e).' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_current == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await PartnerService().updateCompany(
        id: _current!.id,
        companyData: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_businessNumberCtrl.text.trim().isNotEmpty)
            'businessNumber': _businessNumberCtrl.text.trim(),
        },
        logoFile: _logo,
        kycFrontFile: _kycFront,
        kycBackFile: _kycBack,
      );
      // Recharge le profil pour repartir sur le bon écran (redirect du routeur).
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) context.go('/partner/pending');
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Corriger mon dossier',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.mobiliBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_current?.rejectionReason != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Motif du rejet précédent',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _current!.rejectionReason!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la compagnie',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _required(v, 'Nom'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email officiel (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _required(v, 'Téléphone'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° RCCM / contribuable (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Logo (laissez vide pour garder l\'actuel)',
                      style: TextStyle(color: AppColors.gray500, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _PickerBox(file: _logo, onTap: _pickLogo, label: 'Logo'),
                    const SizedBox(height: 20),
                    const Text(
                      'Pièce d\'identité (laissez vide pour garder les documents actuels, remplacez uniquement si le motif de rejet le concerne)',
                      style: TextStyle(color: AppColors.gray500, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerBox(
                            file: _kycFront,
                            onTap: _pickKycFront,
                            label: 'Recto',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickerBox(
                            file: _kycBack,
                            onTap: _pickKycBack,
                            label: 'Verso',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mobiliYellow,
                          foregroundColor: AppColors.mobiliBlueDeep,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: AppColors.mobiliBlueDeep,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Soumettre à nouveau',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.file,
    required this.onTap,
    required this.label,
  });
  final File? file;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: file != null ? AppColors.mobiliBlue : AppColors.gray200,
          width: file != null ? 2 : 1,
        ),
      ),
      child: file != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            )
          : Center(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.gray400, fontSize: 12),
              ),
            ),
    ),
  );
}
