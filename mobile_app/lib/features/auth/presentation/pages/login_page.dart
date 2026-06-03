// lib/features/auth/presentation/pages/login_page.dart
//
// Écran de connexion Mobili.
// Navigation : utilise GoRouter — aucune route codée en dur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/mobili_button.dart';
import '../../../shared/widgets/mobili_error_widget.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Validation locale ──────────────────────────────────────────────────────

  String? _validateLogin(String? v) {
    if (v == null || v.trim().isEmpty) return 'Identifiant requis.';
    if (v.trim().length < 3) return 'Minimum 3 caractères.';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Mot de passe requis.';
    if (v.length < 6) return 'Minimum 6 caractères.';
    return null;
  }

  // ── Soumission ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          login: _loginCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (success && mounted) {
      // GoRouter redirige automatiquement via le redirect de l'AppRouter
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ─────────────────────────────────────────────
                _Header(isDark: isDark),
                const SizedBox(height: 36),

                // ── Formulaire ─────────────────────────────────────────
                _FormCard(
                  isDark: isDark,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bandeau d'erreur API globale
                        if (state?.hasError == true &&
                            state?.errorMessage != null) ...[
                          MobiliErrorBanner(
                            message: state!.errorMessage!,
                            onDismiss: () => ref
                                .read(authProvider.notifier)
                                .clearError(),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Erreurs de champ API (Spring Boot MOB-003 / @Valid validation)
                        if (state?.fieldErrors?.isNotEmpty == true) ...[
                          MobiliFieldErrors(errors: state!.fieldErrors!),
                          const SizedBox(height: 20),
                        ],

                        // Identifiant
                        _MobiliTextField(
                          controller: _loginCtrl,
                          label: 'Identifiant',
                          hint: 'votre_login',
                          icon: Icons.person_outline_rounded,
                          validator: _validateLogin,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.text,
                          enabled: !isLoading,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),

                        // Mot de passe
                        _MobiliTextField(
                          controller: _passwordCtrl,
                          label: 'Mot de passe',
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          validator: _validatePassword,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
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
                            onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Bouton connexion
                        MobiliButton(
                          label: 'Se connecter',
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets locaux (Privés à ce fichier)
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.mobiliBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Mobili',
                style: AppTextStyles.displaySmall.copyWith(
                  color: isDark
                      ? AppColors.darkOnSurface
                      : AppColors.mobiliBlueDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Bon retour !',
            style: AppTextStyles.headlineLarge.copyWith(
              color: isDark
                  ? AppColors.darkOnSurface
                  : AppColors.mobiliBlueDeep,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Connectez-vous pour accéder à vos trajets.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: isDark
                  ? AppColors.darkOnSurfaceVar
                  : AppColors.gray600,
            ),
          ),
        ],
      );
}

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

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subColor =
        isDark ? AppColors.darkOnSurfaceVar : AppColors.gray600;
    final accentColor =
        isDark ? AppColors.mobiliYellowSoft : AppColors.mobiliBlue;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pas encore de compte ? ',
              style: AppTextStyles.bodyMedium.copyWith(color: subColor),
            ),
            GestureDetector(
              onTap: () => context.push('/register'),
              child: Text(
                "S'inscrire",
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
          onTap: () => context.push('/register-chauffeur'),
          child: Text(
            'Devenir chauffeur partenaire →',
            style: AppTextStyles.bodySmall.copyWith(color: accentColor),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _MobiliTextField extends StatelessWidget {
  const _MobiliTextField({
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