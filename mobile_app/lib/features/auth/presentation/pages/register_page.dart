// lib/features/auth/presentation/pages/register_page.dart
//
// Écran d'inscription voyageur standard Mobili.
// Navigation : GoRouter — aucune route codée en dur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/mobili_button.dart';
import '../../../shared/widgets/mobili_error_widget.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart' show LoginPage; // Permet de conserver une cohérence d'importation globale

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

  // ── Validations locales ────────────────────────────────────────────────────

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
    if (v.length > 255) return 'Maximum 255 caractères.';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Confirmation requise.';
    if (v != _passwordCtrl.text) return 'Les mots de passe ne correspondent pas.';
    return null;
  }

  // ── Soumission ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
          firstname: _firstnameCtrl.text.trim(),
          lastname: _lastnameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          login: _loginCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (success && mounted) {
      // Le redirect global du GoRouter prend automatiquement le relais vers l'accueil
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final state = authState.valueOrNull;
    final isLoading = state?.isLoading ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.gray50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppColors.darkOnSurface : AppColors.mobiliBlueDeep,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Créer un compte',
          style: AppTextStyles.titleLarge.copyWith(
            color: isDark ? AppColors.darkOnSurface : AppColors.mobiliBlueDeep,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sous-titre
              Text(
                'Voyageur standard — accès à la réservation de trajets.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkOnSurfaceVar : AppColors.gray600,
                ),
              ),
              const SizedBox(height: 24),

              // ── Carte formulaire ────────────────────────────────────
              _FormCard(
                isDark: isDark,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bandeau erreur API globale
                      if (state?.hasError == true &&
                          state?.errorMessage != null) ...[
                        MobiliErrorBanner(
                          message: state!.errorMessage!,
                          onDismiss: () =>
                              ref.read(authProvider.notifier).clearError(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Erreurs de validation de champs (MOB-003)
                      if (state?.fieldErrors?.isNotEmpty == true) ...[
                        MobiliFieldErrors(errors: state!.fieldErrors!),
                        const SizedBox(height: 20),
                      ],

                      // Séparateur section
                      _SectionLabel(label: 'Identité', isDark: isDark),
                      const SizedBox(height: 12),

                      // Ligne prénom / nom
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MobiliLocalTextField(
                              controller: _firstnameCtrl,
                              label: 'Prénom',
                              hint: 'Jean',
                              icon: Icons.badge_outlined,
                              validator: _validateFirstname,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MobiliLocalTextField(
                              controller: _lastnameCtrl,
                              label: 'Nom',
                              hint: 'Dupont',
                              icon: Icons.badge_outlined,
                              validator: _validateLastname,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _MobiliLocalTextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        hint: 'jean@exemple.com',
                        icon: Icons.email_outlined,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),

                      _SectionLabel(label: 'Connexion', isDark: isDark),
                      const SizedBox(height: 12),

                      _MobiliLocalTextField(
                        controller: _loginCtrl,
                        label: 'Identifiant',
                        hint: 'jean_dupont',
                        icon: Icons.person_outline_rounded,
                        validator: _validateLogin,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      _MobiliLocalTextField(
                        controller: _passwordCtrl,
                        label: 'Mot de passe',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        validator: _validatePassword,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        isDark: isDark,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          color: isDark
                              ? AppColors.darkOnSurfaceVar
                              : AppColors.gray500,
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _MobiliLocalTextField(
                        controller: _confirmCtrl,
                        label: 'Confirmer le mot de passe',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        validator: _validateConfirm,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        enabled: !isLoading,
                        isDark: isDark,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          color: isDark
                              ? AppColors.darkOnSurfaceVar
                              : AppColors.gray500,
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // CTA principal
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

              // ── Liens bas ──────────────────────────────────────────
              _FooterLinks(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets locaux (Privés à ce fichier)
// ─────────────────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.isDark, required this.child});
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark ? null : AppColors.shadowMd,
        ),
        child: child,
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelMedium.copyWith(
              color: isDark ? AppColors.mobiliYellowSoft : AppColors.mobiliBlue,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              thickness: 1,
              color: isDark ? AppColors.darkOutline : AppColors.gray100,
            ),
          ),
        ],
      );
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subColor = isDark ? AppColors.darkOnSurfaceVar : AppColors.gray600;
    final accentColor = isDark ? AppColors.mobiliYellowSoft : AppColors.mobiliBlue;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Déjà un compte ? ',
              style: AppTextStyles.bodyMedium.copyWith(color: subColor),
            ),
            GestureDetector(
              onTap: () => context.pop(),
              child: Text(
                'Se connecter',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push('/register-company'),
          child: Text(
            'Inscrire une société de transport →',
            style: AppTextStyles.bodySmall.copyWith(color: accentColor),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _MobiliLocalTextField extends StatelessWidget {
  const _MobiliLocalTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.enabled = true,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkOutline : AppColors.gray200;
    final focusColor = isDark ? AppColors.mobiliYellow : AppColors.mobiliBlue;
    final labelColor = isDark ? AppColors.darkOnSurfaceVar : AppColors.gray600;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.mobiliBlueDeep;
    final fillColor = isDark ? AppColors.darkSurfaceRaised : AppColors.gray50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(color: labelColor),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          style: AppTextStyles.bodyMedium.copyWith(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkOutline : AppColors.gray400,
            ),
            prefixIcon: Icon(icon, size: 20, color: labelColor),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusColor, width: 1.5),
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