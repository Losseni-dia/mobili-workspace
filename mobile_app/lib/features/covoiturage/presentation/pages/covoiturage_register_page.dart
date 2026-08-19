import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/models/mobili_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_error_widget.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/providers/auth_provider.dart';

/// Inscription conducteur covoiturage — `POST /auth/register-carpool-chauffeur`.
///
/// Endpoint public (pas besoin d'être connecté). Les 4 fichiers (CNI recto,
/// CNI verso, photo du conducteur, photo du véhicule) sont obligatoires côté
/// backend ; le dossier part au statut PENDING en attente de validation admin.
class CovoiturageRegisterPage extends ConsumerStatefulWidget {
  const CovoiturageRegisterPage({super.key});

  @override
  ConsumerState<CovoiturageRegisterPage> createState() =>
      _CovoiturageRegisterPageState();
}

class _CovoiturageRegisterPageState
    extends ConsumerState<CovoiturageRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _firstnameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _vehicleBrandCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController();
  final _greyCardCtrl = TextEditingController();

  DateTime? _idValidUntil;
  File? _idFront;
  File? _idBack;
  File? _driverPhoto;
  File? _vehiclePhoto;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _loginCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _vehicleBrandCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _vehicleColorCtrl.dispose();
    _greyCardCtrl.dispose();
    super.dispose();
  }

  Future<File?> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return picked != null ? File(picked.path) : null;
  }

  Future<void> _pickIdValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
    );
    if (picked != null) setState(() => _idValidUntil = picked);
  }

  String? _required(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field requis(e).';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_confirmPasswordCtrl.text != _passwordCtrl.text) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas.');
      return;
    }
    if (_idValidUntil == null) {
      setState(
          () => _errorMessage = 'La date de validité de la CNI est requise.');
      return;
    }
    if (_idFront == null ||
        _idBack == null ||
        _driverPhoto == null ||
        _vehiclePhoto == null) {
      setState(() => _errorMessage =
          'Les 4 photos sont obligatoires (CNI recto/verso, vous, véhicule).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await AuthService().registerCarpoolChauffeur(
        userData: {
          'firstname': _firstnameCtrl.text.trim(),
          'lastname': _lastnameCtrl.text.trim(),
          'login': _loginCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'idValidUntil': _idValidUntil!.toIso8601String().substring(0, 10),
          'vehicleBrand': _vehicleBrandCtrl.text.trim(),
          'vehiclePlate': _vehiclePlateCtrl.text.trim(),
          'vehicleColor': _vehicleColorCtrl.text.trim(),
          'greyCardNumber': _greyCardCtrl.text.trim(),
        },
        idFront: _idFront!,
        idBack: _idBack!,
        driverPhoto: _driverPhoto!,
        vehiclePhoto: _vehiclePhoto!,
      );
      ref.read(authProvider.notifier).setProfile(profile);
      if (mounted) context.go('/covoiturage');
    } on MobiliException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Une erreur inattendue est survenue.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: const MobiliAppBar(
        title: 'Devenir conducteur',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                MobiliErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),
              ],
              const _SectionLabel(label: 'Identité'),
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
                label: 'Email (facultatif)',
                keyboardType: TextInputType.emailAddress,
                // Optionnel côté backend (RegisterCarpoolChauffeurDTO.email : @Email seul,
                // pas @NotBlank) — même regex que register_page.dart pour cohérence.
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final emailRx =
                      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$');
                  if (!emailRx.hasMatch(v.trim())) return 'Email invalide.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _phoneCtrl,
                label: 'Téléphone',
                keyboardType: TextInputType.phone,
                maxLength: 20, // RegisterCarpoolChauffeurDTO.phone : @Size(max = 20)
                validator: (v) => _required(v, 'Téléphone'),
              ),
              const SizedBox(height: 20),
              const _SectionLabel(label: 'Connexion'),
              const SizedBox(height: 12),
              _Field(
                controller: _loginCtrl,
                label: 'Identifiant',
                validator: (v) => _required(v, 'Identifiant'),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _passwordCtrl,
                label: 'Mot de passe (6 caractères minimum)',
                obscureText: true,
                // Miroir de RegisterCarpoolChauffeurDTO.password (@Size min=6), aligné sur le web.
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Mot de passe requis.';
                  if (v.length < 6) return 'Minimum 6 caractères.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _confirmPasswordCtrl,
                label: 'Confirmer le mot de passe',
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirmation requise.';
                  if (v != _passwordCtrl.text) {
                    return 'Les mots de passe ne correspondent pas.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const _SectionLabel(label: 'Pièce d\'identité'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickIdValidUntil,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined,
                          size: 18, color: AppColors.gray400),
                      const SizedBox(width: 10),
                      Text(
                        _idValidUntil == null
                            ? 'Date de validité de la CNI'
                            : 'Valide jusqu\'au ${_idValidUntil!.day}/${_idValidUntil!.month}/${_idValidUntil!.year}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _idValidUntil == null
                              ? AppColors.gray400
                              : AppColors.mobiliBlueDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PhotoPicker(
                      label: 'CNI recto',
                      file: _idFront,
                      onPick: () async {
                        final f = await _pickImage();
                        if (f != null) setState(() => _idFront = f);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PhotoPicker(
                      label: 'CNI verso',
                      file: _idBack,
                      onPick: () async {
                        final f = await _pickImage();
                        if (f != null) setState(() => _idBack = f);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionLabel(label: 'Vous & votre véhicule'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PhotoPicker(
                      label: 'Votre photo',
                      file: _driverPhoto,
                      onPick: () async {
                        final f = await _pickImage();
                        if (f != null) setState(() => _driverPhoto = f);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PhotoPicker(
                      label: 'Photo véhicule',
                      file: _vehiclePhoto,
                      onPick: () async {
                        final f = await _pickImage();
                        if (f != null) setState(() => _vehiclePhoto = f);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _vehicleBrandCtrl,
                label: 'Marque du véhicule',
                maxLength: 80, // RegisterCarpoolChauffeurDTO.vehicleBrand : @Size(max = 80)
                validator: (v) => _required(v, 'Marque'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _vehiclePlateCtrl,
                      label: 'Plaque',
                      maxLength: 32, // vehiclePlate : @Size(max = 32)
                      validator: (v) => _required(v, 'Plaque'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _vehicleColorCtrl,
                      label: 'Couleur',
                      maxLength: 40, // vehicleColor : @Size(max = 40)
                      validator: (v) => _required(v, 'Couleur'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _greyCardCtrl,
                label: 'Numéro de carte grise',
                maxLength: 64, // greyCardNumber : @Size(max = 64)
                validator: (v) => _required(v, 'Numéro de carte grise'),
              ),
              const SizedBox(height: 28),
              MobiliButton(
                label: 'Envoyer mon dossier',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),
              const SizedBox(height: 16),
              Text(
                'Votre dossier sera examiné par un administrateur Mobili '
                'avant que vous puissiez publier des trajets.',
                textAlign: TextAlign.center,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.gray500),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              )),
          const SizedBox(width: 10),
          const Expanded(
              child: Divider(thickness: 1, color: AppColors.gray200)),
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
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.white,
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
            borderSide: const BorderSide(color: AppColors.mobiliBlue, width: 2),
          ),
        ),
      );
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.label,
    required this.file,
    required this.onPick,
  });

  final String label;
  final File? file;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPick,
        child: Container(
          height: 110,
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
                  child: Image.file(file!,
                      fit: BoxFit.cover, width: double.infinity),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.gray300, size: 26),
                    const SizedBox(height: 6),
                    Text(label,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.gray400, fontSize: 11)),
                  ],
                ),
        ),
      );
}
