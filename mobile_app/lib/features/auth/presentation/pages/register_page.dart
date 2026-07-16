import 'dart:io';

import 'package:flutter/gestures.dart';
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
  final _phoneCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  File? _avatarFile;

  // CGU / RGPD
  bool _acceptedCGU = false;
  bool _acceptedRGPD = false;
  bool _showCGUError = false;
  bool _showRGPDError = false;

@override
  void initState() {
    super.initState();
    // Dès que l'utilisateur retouche l'email ou le login après une erreur de
    // doublon, on efface l'erreur API stockée dans authProvider — sinon le
    // validator continue de renvoyer l'ancienne erreur (champ "figé") même
    // après correction, car il lit l'état du dernier build, pas le texte
    // actuel du champ.
 _emailCtrl.addListener(_clearEmailFieldError);
    _loginCtrl.addListener(_clearLoginFieldError);
    _phoneCtrl.addListener(_clearPhoneFieldError);
  }

  void _clearEmailFieldError() {
    final fieldErrors = ref.read(authProvider).valueOrNull?.fieldErrors;
    if (fieldErrors?.containsKey('email') == true) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  void _clearLoginFieldError() {
    final fieldErrors = ref.read(authProvider).valueOrNull?.fieldErrors;
    if (fieldErrors?.containsKey('login') == true) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  void _clearPhoneFieldError() {
    final fieldErrors = ref.read(authProvider).valueOrNull?.fieldErrors;
    if (fieldErrors?.containsKey('phone') == true) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  @override
 void dispose() {
    _emailCtrl.removeListener(_clearEmailFieldError);
    _loginCtrl.removeListener(_clearLoginFieldError);
    _phoneCtrl.removeListener(_clearPhoneFieldError);
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
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
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  String? _required(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field requis(e).';
    return null;
  }

  String? _validateFirstname(String? v) => _required(v, 'Prénom');
  String? _validateLastname(String? v) => _required(v, 'Nom');

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final emailRx = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w]{2,}$');
    if (!emailRx.hasMatch(v.trim())) return 'Email invalide.';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Téléphone requis.';
    if (v.trim().length < 8) return 'Numéro invalide.';
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
    if (v.length < 8) return 'Minimum 8 caractères.';
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
    final formValid = _formKey.currentState!.validate();
    setState(() {
      _showCGUError = !_acceptedCGU;
      _showRGPDError = !_acceptedRGPD;
    });
    if (!formValid || !_acceptedCGU || !_acceptedRGPD) return;

    final success = await ref.read(authProvider.notifier).register(
          firstname: _firstnameCtrl.text.trim(),
          lastname: _lastnameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          login: _loginCtrl.text.trim(),
          password: _passwordCtrl.text,
          phone: _phoneCtrl.text.trim(),
          avatarFile: _avatarFile,
        );

    if (!success && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
    }

    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.successSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.success, size: 44),
                ),
                const SizedBox(height: 20),
                Text('Compte créé avec succès !',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  'Connectez-vous avec votre identifiant et mot de passe.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.gray500, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Se connecter',
                      style: AppTextStyles.buttonPrimary.copyWith(
                          color: AppColors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      });
    }
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
                                    fontWeight: FontWeight.w800))),
                        const SizedBox(height: 4),
                        Center(
                            child: Text('Voyagez partout en Afrique',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.white
                                        .withValues(alpha: 0.7)))),
                        const SizedBox(height: 24),
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
                              )
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // On n'affiche le banner générique QUE si
                                // l'erreur n'a pas déjà une erreur de champ
                                // dédiée (email/login) — sinon le message
                                // s'affiche sous le champ concerné et on
                                // évite le doublon visuel.
                                if (state?.hasError == true &&
                                    state?.errorMessage != null &&
                                    state?.fieldErrors?.isNotEmpty != true) ...[
                                  MobiliErrorBanner(
                                    message: state!.errorMessage!,
                                    onDismiss: () => ref
                                        .read(authProvider.notifier)
                                        .clearError(),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Avatar
                                Center(
                                  child: Column(children: [
                                    Text('PHOTO DE PROFIL',
                                        style:
                                            AppTextStyles.labelMedium.copyWith(
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
                                                child: Image.file(_avatarFile!,
                                                    fit: BoxFit.cover))
                                            : const Center(
                                                child: Icon(
                                                    Icons.person_rounded,
                                                    color: AppColors.white,
                                                    size: 40)),
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
                                  ]),
                                ),
                                const SizedBox(height: 20),

                                // Identité
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
                                    )),
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
                                    )),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _Field(
                                  controller: _emailCtrl,
                                  label: 'Email (facultatif)',
                                  hint: 'maya@exemple.com',
                                  icon: Icons.email_outlined,
                                  validator: (v) {
                                    final apiError =
                                        state?.fieldErrors?['email'];
                                    if (apiError != null) return apiError;
                                    return _validateEmail(v);
                                  },
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  enabled: !isLoading,
                                  autovalidate: true,
                                ),
                                const SizedBox(height: 14),
                                _Field(
                                  controller: _phoneCtrl,
                                  label: 'Téléphone',
                                  hint: '+225 07 00 00 00 00',
                                  icon: Icons.phone_outlined,
                                  validator: (v) {
                                    final apiError =
                                        state?.fieldErrors?['phone'];
                                    if (apiError != null) return apiError;
                                    return _validatePhone(v);
                                  },
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  enabled: !isLoading,
                                  autovalidate: true,
                                ),
                                const SizedBox(height: 20),

                                // Connexion
                                const _SectionLabel(label: 'Connexion'),
                                const SizedBox(height: 12),
                                _Field(
                                  controller: _loginCtrl,
                                  label: 'Identifiant',
                                  hint: 'maya123',
                                  icon: Icons.badge_outlined,
                                  validator: (v) {
                                    final apiError =
                                        state?.fieldErrors?['login'];
                                    if (apiError != null) return apiError;
                                    return _validateLogin(v);
                                  },
                                  textInputAction: TextInputAction.next,
                                  enabled: !isLoading,
                                  autovalidate: true,
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
                                  helperText: '8 caractères minimum',
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

                                // ── CGU / RGPD ────────────────────
                                const _SectionLabel(
                                    label: 'Consentements obligatoires'),
                                const SizedBox(height: 12),

                                _ConsentCheckbox(
                                  value: _acceptedCGU,
                                  hasError: _showCGUError,
                                  onChanged: (v) => setState(() {
                                    _acceptedCGU = v ?? false;
                                    if (_acceptedCGU) _showCGUError = false;
                                  }),
                                  text: RichText(
                                    text: TextSpan(
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.gray700,
                                          fontSize: 13,
                                          height: 1.4),
                                      children: [
                                        const TextSpan(
                                            text: "J'ai lu et j'accepte les "),
                                        TextSpan(
                                          text:
                                              "Conditions Générales d'Utilisation",
                                          style: const TextStyle(
                                            color: AppColors.mobiliBlue,
                                            fontWeight: FontWeight.w700,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap =
                                                () => context.push('/cgu'),
                                        ),
                                        const TextSpan(text: ' de Mobili.'),
                                      ],
                                    ),
                                  ),
                                  errorText:
                                      'Vous devez accepter les CGU pour continuer.',
                                ),
                                const SizedBox(height: 10),

                                _ConsentCheckbox(
                                  value: _acceptedRGPD,
                                  hasError: _showRGPDError,
                                  onChanged: (v) => setState(() {
                                    _acceptedRGPD = v ?? false;
                                    if (_acceptedRGPD) _showRGPDError = false;
                                  }),
                                  text: RichText(
                                    text: TextSpan(
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.gray700,
                                          fontSize: 13,
                                          height: 1.4),
                                      children: [
                                        const TextSpan(
                                            text:
                                                "J'accepte le traitement de mes données personnelles conformément à la "),
                                        TextSpan(
                                          text: "Politique de Confidentialité",
                                          style: const TextStyle(
                                            color: AppColors.mobiliBlue,
                                            fontWeight: FontWeight.w700,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => context
                                                .push('/confidentialite'),
                                        ),
                                        const TextSpan(
                                            text: ' (conformité RGPD).'),
                                      ],
                                    ),
                                  ),
                                  errorText:
                                      "Vous devez accepter la politique de confidentialité pour continuer.",
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
                                    color: AppColors.white
                                        .withValues(alpha: 0.8))),
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Text('Se connecter',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.mobiliYellow,
                                      fontWeight: FontWeight.w700)),
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

// ── Checkbox consentement ────────────────────────────────────────────────────

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.hasError,
    required this.onChanged,
    required this.text,
    required this.errorText,
  });

  final bool value;
  final bool hasError;
  final ValueChanged<bool?> onChanged;
  final Widget text;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: hasError
                ? AppColors.dangerSoft
                : value
                    ? AppColors.successSoft
                    : AppColors.gray50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasError
                  ? AppColors.danger
                  : value
                      ? AppColors.success
                      : AppColors.gray200,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.mobiliBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                  child: text,
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(errorText,
                      style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Pattern transport ────────────────────────────────────────────────────────

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

// ── Section label ────────────────────────────────────────────────────────────

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
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          const Expanded(
              child: Divider(thickness: 1, color: AppColors.gray100)),
        ],
      );
}

// ── Champ texte ──────────────────────────────────────────────────────────────

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
    this.helperText,
  });

  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;
  final Widget? suffixIcon;
  final bool autovalidate;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
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
            helperText: helperText,
            helperStyle: AppTextStyles.bodySmall.copyWith(
              color: AppColors.gray400,
              fontSize: 11,
            ),
            prefixIcon: Icon(icon, size: 20, color: AppColors.gray400),
            suffixIcon: suffixIcon,
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
