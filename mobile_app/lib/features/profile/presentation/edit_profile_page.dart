import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobili/features/auth/domain/models/profile_dto.dart';
import 'package:mobili/features/auth/providers/auth_provider.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstnameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _oldPasswordCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  File? _avatarFile;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider);
    _firstnameCtrl = TextEditingController(text: profile?.firstname ?? '');
    _lastnameCtrl = TextEditingController(text: profile?.lastname ?? '');
    _emailCtrl = TextEditingController(text: profile?.email ?? '');
    _phoneCtrl = TextEditingController(text: profile?.phone ?? '');
    _oldPasswordCtrl = TextEditingController();
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  String? _validateNewPassword(String? v) {
    if (v == null || v.isEmpty) return null;
    if (v.length < 8) return 'Minimum 8 caractères.';
    if (_oldPasswordCtrl.text.isNotEmpty && v == _oldPasswordCtrl.text) {
      return 'Le nouveau mot de passe doit être différent de l\'ancien.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (_newPasswordCtrl.text.isEmpty) return null;
    if (v == null || v.isEmpty) return 'Confirmation requise.';
    if (v != _newPasswordCtrl.text) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }

  String? _validateOldPassword(String? v) {
    if (_newPasswordCtrl.text.isEmpty) return null;
    if (v == null || v.isEmpty) {
      return 'Ancien mot de passe requis pour changer.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    // Vérification côté client : si nouveau mdp rempli, ancien obligatoire
    if (_newPasswordCtrl.text.isNotEmpty && _oldPasswordCtrl.text.isEmpty) {
      setState(() => _error = 'Veuillez saisir votre ancien mot de passe.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final formData = FormData.fromMap({
        'user': MultipartFile.fromString(
          jsonEncode({
            'firstname': _firstnameCtrl.text.trim(),
            'lastname': _lastnameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'login': profile.login,
            if (_newPasswordCtrl.text.isNotEmpty)
              'password': _newPasswordCtrl.text,
            if (_oldPasswordCtrl.text.isNotEmpty)
              'oldPassword': _oldPasswordCtrl.text,
          }),
          contentType: DioMediaType('application', 'json'),
        ),
        if (_avatarFile != null)
          'avatar': await MultipartFile.fromFile(
            _avatarFile!.path,
            filename: _avatarFile!.path.split('/').last,
          ),
      });

      await ApiClient.instance.dio.put(
        '/users/${profile.id}',
        data: formData,
      );

      // Rafraîchir le profil
      final updatedResponse =
          await ApiClient.instance.dio.get<Map<String, dynamic>>('/auth/me');
      final updatedProfileDto = ProfileDto.fromJson(updatedResponse.data!);
      ref.read(authProvider.notifier).setProfile(updatedProfileDto);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour ✓'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error =
          'Erreur lors de la mise à jour. Vérifiez votre ancien mot de passe.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: const MobiliAppBar(
        title: 'Modifier le profil',
        showBackButton: true,
        titleFontSize: 16,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.mobiliBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.mobiliYellow, width: 3),
                        ),
                        child: _avatarFile != null
                            ? ClipOval(
                                child:
                                    Image.file(_avatarFile!, fit: BoxFit.cover))
                            : profile?.avatarUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      '${ApiConstants.baseUrl}/uploads/${profile!.avatarUrl}',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.person_rounded,
                                          color: AppColors.white,
                                          size: 40),
                                    ),
                                  )
                                : const Icon(Icons.person_rounded,
                                    color: AppColors.white, size: 40),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.mobiliYellow,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 14, color: AppColors.mobiliBlueDeep),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Erreur ──────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Section Informations personnelles ───────────────────
              _sectionLabel('Informations personnelles'),
              const SizedBox(height: 12),
              _buildField(
                _firstnameCtrl,
                'Prénom',
                Icons.person_outline_rounded,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Prénom requis' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                _lastnameCtrl,
                'Nom',
                Icons.person_outline_rounded,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                _emailCtrl,
                'Email (facultatif)',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _buildField(
                _phoneCtrl,
                'Téléphone',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Téléphone requis' : null,
              ),
              const SizedBox(height: 24),

              // ── Section Mot de passe ────────────────────────────────
              _sectionLabel('Changer le mot de passe'),
              const SizedBox(height: 4),
              Text(
                'Laissez ces champs vides si vous ne souhaitez pas changer votre mot de passe.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.gray400, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Ancien mot de passe
              _buildPasswordField(
                controller: _oldPasswordCtrl,
                label: 'Ancien mot de passe',
                obscure: _obscureOld,
                onToggle: () => setState(() => _obscureOld = !_obscureOld),
                validator: _validateOldPassword,
              ),
              const SizedBox(height: 14),

              // Nouveau mot de passe
              _buildPasswordField(
                controller: _newPasswordCtrl,
                label: 'Nouveau mot de passe',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: _validateNewPassword,
              ),
              const SizedBox(height: 14),

              // Confirmer nouveau mot de passe
              _buildPasswordField(
                controller: _confirmPasswordCtrl,
                label: 'Confirmer le nouveau mot de passe',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: _validateConfirmPassword,
              ),
              const SizedBox(height: 28),

              MobiliButton(
                label: 'Enregistrer',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
                fullWidth: true,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.mobiliBlue,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(thickness: 1, color: AppColors.gray100)),
      ],
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.gray600,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          validator: validator,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.mobiliBlueDeep),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: AppColors.gray400),
            filled: true,
            fillColor: AppColors.gray50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gray200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gray200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.mobiliBlue, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.gray600,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.mobiliBlueDeep),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 20, color: AppColors.gray400),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.gray400,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: AppColors.gray50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gray200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gray200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.mobiliBlue, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
