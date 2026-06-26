import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobili/features/auth/domain/models/profile_dto.dart';
import 'package:mobili/features/auth/providers/auth_provider.dart';

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
  late final TextEditingController _passwordCtrl;
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
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

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
            if (_passwordCtrl.text.isNotEmpty) 'password': _passwordCtrl.text,
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
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text('Modifier le profil',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
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
                                      'https://api.my-mobili.com/v1/uploads/${profile!.avatarUrl}',
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

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // Champs
              _buildField(
                  _firstnameCtrl, 'Prénom', Icons.person_outline_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Prénom requis' : null),
              const SizedBox(height: 14),
              _buildField(_lastnameCtrl, 'Nom', Icons.person_outline_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Nom requis' : null),
              const SizedBox(height: 14),
              _buildField(
                  _emailCtrl, 'Email (facultatif)', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _buildField(_phoneCtrl, 'Téléphone', Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Téléphone requis'
                      : null),
              const SizedBox(height: 14),
              _buildField(_passwordCtrl, 'Nouveau mot de passe (facultatif)',
                  Icons.lock_outline_rounded,
                  obscureText: true),
              const SizedBox(height: 28),

              MobiliButton(
                label: 'Enregistrer',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
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
          obscureText: obscureText,
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
          ),
        ),
      ],
    );
  }
}
