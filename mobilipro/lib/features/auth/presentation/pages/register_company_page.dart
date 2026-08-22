import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Inscription "dirigeant société" — `POST /auth/register-company`.
/// Crée le responsable + la compagnie en une fois et connecte directement
/// (le backend renvoie un token).
class RegisterCompanyPage extends ConsumerStatefulWidget {
  const RegisterCompanyPage({super.key});

  @override
  ConsumerState<RegisterCompanyPage> createState() =>
      _RegisterCompanyPageState();
}

class _RegisterCompanyPageState extends ConsumerState<RegisterCompanyPage> {
  final _formKey = GlobalKey<FormState>();

  final _firstnameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _businessNumberCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  File? _logo;
  File? _kycFront;
  File? _kycBack;
  File? _transportCardFront;
  File? _transportCardBack;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _businessNumberCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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

  Future<void> _pickTransportCardFront() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _transportCardFront = File(picked.path));
  }

  Future<void> _pickTransportCardBack() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _transportCardBack = File(picked.path));
  }

  String? _required(String? v, String field) =>
      v == null || v.trim().isEmpty ? '$field requis(e).' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kycFront == null || _kycBack == null) {
      setState(
        () => _errorMessage =
            'Ajoutez les photos recto et verso de votre carte d\'identité.',
      );
      return;
    }
    if (_transportCardFront == null || _transportCardBack == null) {
      setState(
        () => _errorMessage =
            'Ajoutez les photos recto et verso de votre carte de transporteur.',
      );
      return;
    }
    setState(() => _errorMessage = null);

    final ok = await ref
        .read(authProvider.notifier)
        .registerCompany(
          companyData: {
            'firstname': _firstnameCtrl.text.trim(),
            'lastname': _lastnameCtrl.text.trim(),
            'login': _loginCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'password': _passwordCtrl.text,
            'companyName': _companyNameCtrl.text.trim(),
            'companyEmail': _companyEmailCtrl.text.trim(),
            'companyPhone': _companyPhoneCtrl.text.trim(),
            if (_businessNumberCtrl.text.trim().isNotEmpty)
              'businessNumber': _businessNumberCtrl.text.trim(),
          },
          logoFile: _logo,
          kycFrontFile: _kycFront!,
          kycBackFile: _kycBack!,
          transportCardFrontFile: _transportCardFront!,
          transportCardBackFile: _transportCardBack!,
        );

    if (ok && mounted) {
      context.go('/partner/dashboard');
  } else if (mounted) {
      final authState = ref.read(authProvider).valueOrNull;
      final hasFieldErrors = (authState?.fieldErrors?.isNotEmpty) ?? false;
      setState(
        () => _errorMessage = hasFieldErrors
            ? null
            : (authState?.errorMessage ?? 'Une erreur est survenue.'),
      );
      if (hasFieldErrors) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _formKey.currentState!.validate();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).valueOrNull?.isLoading ?? false;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Inscrire ma compagnie',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const _SectionLabel(label: 'Responsable'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _firstnameCtrl,
                      label: 'Prénom',
                      validator: (v) => _required(v, 'Prénom'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _lastnameCtrl,
                      label: 'Nom',
                      validator: (v) => _required(v, 'Nom'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _emailCtrl,
                label: 'Email du responsable (optionnel)',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final emailRx = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w]{2,}$');
                  return emailRx.hasMatch(v.trim()) ? null : 'Email invalide.';
                },
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _phoneCtrl,
                label: 'Téléphone du responsable',
                keyboardType: TextInputType.phone,
                onChanged: (_) {
                  ref.read(authProvider.notifier).clearFieldErrors();
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                validator: (v) {
                  final apiError = ref
                      .watch(authProvider)
                      .valueOrNull
                      ?.fieldErrors?['phone'];
                  if (apiError != null) return apiError;
                  if (v == null || v.trim().isEmpty) return 'Téléphone requis.';
                  if (v.trim().length < 8) return 'Numéro invalide.';
                  return null;
                },
                autovalidate: true,
              ),
              const SizedBox(height: 12),
            _Field(
                controller: _loginCtrl,
                label: 'Identifiant',
                onChanged: (_) {
                  ref.read(authProvider.notifier).clearFieldErrors();
                  if (_errorMessage != null)
                    setState(() => _errorMessage = null);
                },
                validator: (v) {
                  final apiError = ref
                      .watch(authProvider)
                      .valueOrNull
                      ?.fieldErrors?['login'];
                  if (apiError != null) return apiError;
                  return _required(v, 'Identifiant');
                },
                autovalidate: true,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _passwordCtrl,
                label: 'Mot de passe (6 caractères minimum)',
                obscureText: _obscurePassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Mot de passe requis.';
                  if (v.length < 6) return 'Minimum 6 caractères.';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.gray400,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _confirmPasswordCtrl,
                label: 'Confirmer le mot de passe',
                obscureText: _obscureConfirm,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirmation requise.';
                  if (v != _passwordCtrl.text) {
                    return 'Les mots de passe ne correspondent pas.';
                  }
                  return null;
                },
                autovalidate: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.gray400,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 20),

              const _SectionLabel(label: 'Compagnie'),
              const SizedBox(height: 12),
              _Field(
                controller: _companyNameCtrl,
                label: 'Nom de la compagnie',
                validator: (v) => _required(v, 'Nom de la compagnie'),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _companyEmailCtrl,
                label: 'Email officiel (optionnel)',
                keyboardType: TextInputType.emailAddress,
               onChanged: (_) {
                  ref.read(authProvider.notifier).clearFieldErrors();
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                validator: (v) {
                  final apiError = ref
                      .watch(authProvider)
                      .valueOrNull
                      ?.fieldErrors?['companyEmail'];
                  if (apiError != null) return apiError;
                  if (v == null || v.trim().isEmpty) return null;
                  final emailRx = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w]{2,}$');
                  return emailRx.hasMatch(v.trim()) ? null : 'Email invalide.';
                },
              ),
              const SizedBox(height: 12),
            _Field(
                controller: _companyPhoneCtrl,
                label: 'Téléphone',
                keyboardType: TextInputType.phone,
                autovalidate: true,
                onChanged: (_) {
                  ref.read(authProvider.notifier).clearFieldErrors();
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                validator: (v) {
                  final apiError = ref
                      .watch(authProvider)
                      .valueOrNull
                      ?.fieldErrors?['companyPhone'];
                  if (apiError != null) return apiError;
                  return _required(v, 'Téléphone');
                },
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _businessNumberCtrl,
                label: 'N° RCCM / contribuable (optionnel)',
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _logo != null
                          ? AppColors.mobiliBlue
                          : AppColors.gray200,
                      width: _logo != null ? 2 : 1,
                    ),
                  ),
                  child: _logo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _logo!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: AppColors.gray300,
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Logo (optionnel)',
                              style: TextStyle(
                                color: AppColors.gray400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionLabel(label: 'Pièce d\'identité du dirigeant'),
              const SizedBox(height: 4),
              const Text(
                'Photos recto et verso de votre carte d\'identité (vérifiées par notre équipe avant activation).',
                style: TextStyle(color: AppColors.gray400, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _KycPicker(
                      label: 'Recto',
                      file: _kycFront,
                      onTap: _pickKycFront,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KycPicker(
                      label: 'Verso',
                      file: _kycBack,
                      onTap: _pickKycBack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionLabel(label: 'Carte de transporteur'),
              const SizedBox(height: 4),
              const Text(
                'Photos recto et verso de la carte de transporteur de la compagnie (vérifiées par notre équipe avant activation).',
                style: TextStyle(color: AppColors.gray400, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _KycPicker(
                      label: 'Recto',
                      file: _transportCardFront,
                      onTap: _pickTransportCardFront,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KycPicker(
                      label: 'Verso',
                      file: _transportCardBack,
                      onTap: _pickTransportCardBack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliYellow,
                    foregroundColor: AppColors.mobiliBlueDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.mobiliBlueDeep,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Créer mon compte',
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

class _KycPicker extends StatelessWidget {
  const _KycPicker({
    required this.label,
    required this.file,
    required this.onTap,
  });
  final String label;
  final File? file;
  final VoidCallback onTap;

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
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.badge_outlined,
                  color: AppColors.gray300,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.gray400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.mobiliBlue,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(thickness: 1, color: AppColors.gray200)),
    ],
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.autovalidate = false,
    this.suffixIcon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autovalidate;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    obscureText: obscureText,
    keyboardType: keyboardType,
    onChanged: onChanged,
    autovalidateMode: autovalidate
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.white,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    ),
  );
}
