import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_error_widget.dart';
import '../../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstnameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  File? _avatarFile;

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  String? _required(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field requis(e).';
    return null;
  }

  String? _validateFirstname(String? v) => _required(v, 'Prénom');
  String? _validateLastname(String? v) => _required(v, 'Nom');

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email requis.';
    final emailRx = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w]{2,}$');
    if (!emailRx.hasMatch(v.trim())) return 'Email invalide.';
    return null;
  }

  String? _validateLogin(String? v) {
    if (v == null || v.trim().isEmpty) return 'Identifiant requis.';
    if (v.trim().length < 3) return 'Minimum 3 caractères.';
    if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(v.trim())) {
      return 'Lettres, chiffres, _ et - uniquement.';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Mot de passe requis.';
    if (v.length < 6) return 'Minimum 6 caractères.';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Confirmation requise.';
    if (v != _passwordCtrl.text) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
          firstname: _firstnameCtrl.text.trim(),
          lastname: _lastnameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          login: _loginCtrl.text.trim(),
          password: _passwordCtrl.text,
          avatarFile: _avatarFile,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final state = authState.valueOrNull;
    final isLoading = state?.isLoading ?? false;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D2280), AppColors.mobiliBlueDeep],
              ),
            ),
          ),
          const Positioned.fill(child: _TransportPattern()),
          Container(color: AppColors.mobiliBlueDeep.withValues(alpha: 0.4)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.white, size: 20),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Text('Créer un compte',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.mobiliYellow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.directions_bus_rounded,
                                color: AppColors.mobiliBlueDeep, size: 30),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text('Rejoignez Mobili',
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                              )),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text('Voyagez partout en Afrique',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.white.withValues(alpha: 0.7),
                              )),
                        ),
                        const SizedBox(height: 24),

                        // Carte formulaire
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 30,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Erreurs API
                                if (state?.hasError == true &&
                                    state?.errorMessage != null) ...[
                                  MobiliErrorBanner(
                                    message: state!.errorMessage!,
                                    onDismiss: () => ref
                                        .read(authProvider.notifier)
                                        .clearError(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (state?.fieldErrors?.isNotEmpty == true) ...[
                                  MobiliFieldErrors(
                                      errors: state!.fieldErrors!),
                                  const SizedBox(height: 16),
                                ],

                                // ── Avatar ────────────────────────
                                Center(
                                  child: Column(
                                    children: [
                                      Text('PHOTO DE PROFIL',
                                          style: AppTextStyles.labelMedium
                                              .copyWith(
                                            color: AppColors.mobiliBlue,
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.w700,
                                          )),
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: _pickAvatar,
                                        child: Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: AppColors.mobiliBlueDeep,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: AppColors.mobiliYellow,
                                                width: 3),
                                          ),
                                          child: _avatarFile != null
                                              ? ClipOval(
                                                  child: Image.file(
                                                      _avatarFile!,
                                                      fit: BoxFit.cover),
                                                )
                                              : const Center(
                                                  child: Icon(
                                                      Icons.person_rounded,
                                                      color: AppColors.white,
                                                      size: 40),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: _pickAvatar,
                                        icon: const Icon(
                                            Icons.photo_library_outlined,
                                            size: 16),
                                        label: const Text('Choisir une photo'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.mobiliBlue,
                                          side: const BorderSide(
                                              color: AppColors.gray200),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Identité ──────────────────────
                                const _SectionLabel(label: 'Identité'),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _Field(
                                        controller: _firstnameCtrl,
                                        label: 'Prénom',
                                        hint: 'Maya',
                                        icon: Icons.person_outline_rounded,
                                        validator: _validateFirstname,
                                        textInputAction: TextInputAction.next,
                                        enabled: !isLoading,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _Field(
                                        controller: _lastnameCtrl,
                                        label: 'Nom',
                                        hint: 'Dia',
                                        icon: Icons.person_outline_rounded,
                                        validator: _validateLastname,
                                        textInputAction: TextInputAction.next,
                                        enabled: !isLoading,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _Field(
                                  controller: _emailCtrl,
                                  label: 'Email',
                                  hint: 'maya@exemple.com',
                                  icon: Icons.email_outlined,
                                  validator: _validateEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  enabled: !isLoading,
                                ),
                                const SizedBox(height: 20),

                                // ── Connexion ─────────────────────
                                const _SectionLabel(label: 'Connexion'),
                                const SizedBox(height: 12),
                                _Field(
                                  controller: _loginCtrl,
                                  label: 'Identifiant',
                                  hint: 'maya123',
                                  icon: Icons.badge_outlined,
                                  validator: _validateLogin,
                                  textInputAction: TextInputAction.next,
                                  enabled: !isLoading,
                                ),
                                const SizedBox(height: 14),
                                _Field(
                                  controller: _passwordCtrl,
                                  label: 'Mot de passe',
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  validator: _validatePassword,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  enabled: !isLoading,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: AppColors.gray400,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _Field(
                                  controller: _confirmCtrl,
                                  label: 'Confirmer le mot de passe',
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  validator: _validateConfirm,
                                  obscureText: _obscureConfirm,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  enabled: !isLoading,
                                  autovalidate: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: AppColors.gray400,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                MobiliButton(
                                  label: 'Créer mon compte',
                                  onPressed: isLoading ? null : _submit,
                                  isLoading: isLoading,
                                  fullWidth: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Déjà un compte ? ',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.white.withValues(alpha: 0.8),
                                )),
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Text('Se connecter',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.mobiliYellow,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportPattern extends StatelessWidget {
  const _TransportPattern();

  static const _icons = [
    Icons.directions_bus_rounded,
    Icons.airport_shuttle_rounded,
    Icons.directions_car_rounded,
    Icons.two_wheeler_rounded,
    Icons.local_taxi_rounded,
    Icons.train_rounded,
    Icons.pedal_bike_rounded,
    Icons.directions_walk_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final items = <Widget>[];
    const cols = 5;
    const rows = 12;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final icon = _icons[(r * cols + c) % _icons.length];
        final offset = (r % 2 == 0) ? 0.0 : cellW * 0.5;
        items.add(Positioned(
          left: c * cellW + offset - cellW * 0.1,
          top: r * cellH,
          child: Icon(icon,
              size: 28, color: AppColors.white.withValues(alpha: 0.08)),
        ));
      }
    }
    return Stack(children: items);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label.toUpperCase(),
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.mobiliBlue,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 10),
          const Expanded(
              child: Divider(thickness: 1, color: AppColors.gray100)),
        ],
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.enabled = true,
    this.suffixIcon,
    this.autovalidate = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;
  final Widget? suffixIcon;
  final bool autovalidate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.gray600,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            )),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          autovalidateMode: autovalidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.mobiliBlueDeep),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.gray300),
            prefixIcon: Icon(icon, size: 20, color: AppColors.gray400),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.gray50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              borderSide:
                  const BorderSide(color: AppColors.mobiliBlue, width: 2),
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
        ),
      ],
    );
  }
}
