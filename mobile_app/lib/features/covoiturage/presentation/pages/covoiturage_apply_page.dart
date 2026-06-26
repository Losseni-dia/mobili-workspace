import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_error_widget.dart';
import '../../providers/covoiturage_provider.dart';

/// Candidature conducteur covoiturage pour un voyageur déjà connecté
/// (`POST /covoiturage/profile/apply`) — rattache le dossier à son compte
/// existant au lieu d'en créer un second, contrairement à
/// [CovoiturageRegisterPage] qui s'adresse aux visiteurs non connectés.
class CovoiturageApplyPage extends ConsumerStatefulWidget {
  const CovoiturageApplyPage({super.key});

  @override
  ConsumerState<CovoiturageApplyPage> createState() =>
      _CovoiturageApplyPageState();
}

class _CovoiturageApplyPageState extends ConsumerState<CovoiturageApplyPage> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleBrandCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController();
  final _greyCardCtrl = TextEditingController();

  DateTime? _idValidUntil;
  File? _idFront;
  File? _idBack;
  File? _driverPhoto;
  File? _vehiclePhoto;
  String? _errorMessage;

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idValidUntil == null) {
      setState(() => _errorMessage = 'La date de validité de la CNI est requise.');
      return;
    }
    if (_idFront == null || _idBack == null || _driverPhoto == null || _vehiclePhoto == null) {
      setState(() => _errorMessage =
          'Les 4 photos sont obligatoires (CNI recto/verso, vous, véhicule).');
      return;
    }
    setState(() => _errorMessage = null);

    final ok = await ref.read(covoiturageApplyNotifierProvider.notifier).submit(
          idValidUntil: _idValidUntil!,
          vehicleBrand: _vehicleBrandCtrl.text.trim(),
          vehiclePlate: _vehiclePlateCtrl.text.trim(),
          vehicleColor: _vehicleColorCtrl.text.trim(),
          greyCardNumber: _greyCardCtrl.text.trim(),
          idFront: _idFront!,
          idBack: _idBack!,
          driverPhoto: _driverPhoto!,
          vehiclePhoto: _vehiclePhoto!,
        );

    if (ok && mounted) context.go('/covoiturage');
  }

  @override
  Widget build(BuildContext context) {
    final applyState = ref.watch(covoiturageApplyNotifierProvider);
    final error = _errorMessage ??
        (applyState.status == CovoiturageApplyStatus.error
            ? applyState.errorMessage
            : null);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text('Devenir conducteur',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                MobiliErrorBanner(
                  message: error,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),
              ],

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mobiliBlueFog,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.mobiliBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Votre dossier sera rattaché à votre compte actuel. '
                        'Vous continuez à utiliser l\'app normalement pendant '
                        'la validation.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.mobiliBlueDeep),
                      ),
                    ),
                  ],
                ),
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
                      const Icon(Icons.event_outlined, size: 18, color: AppColors.gray400),
                      const SizedBox(width: 10),
                      Text(
                        _idValidUntil == null
                            ? 'Date de validité de la CNI'
                            : 'Valide jusqu\'au ${_idValidUntil!.day}/${_idValidUntil!.month}/${_idValidUntil!.year}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _idValidUntil == null ? AppColors.gray400 : AppColors.mobiliBlueDeep,
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
                validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _vehiclePlateCtrl,
                      label: 'Plaque',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _vehicleColorCtrl,
                      label: 'Couleur',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _greyCardCtrl,
                label: 'Numéro de carte grise',
                validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
              ),
              const SizedBox(height: 28),

              MobiliButton(
                label: 'Envoyer ma candidature',
                isLoading: applyState.isSubmitting,
                onPressed: applyState.isSubmitting ? null : _submit,
              ),
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
          const Expanded(child: Divider(thickness: 1, color: AppColors.gray200)),
        ],
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.validator});
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.white,
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
        ),
      );
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.label, required this.file, required this.onPick});
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
                  child: Image.file(file!, fit: BoxFit.cover, width: double.infinity),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: AppColors.gray300, size: 26),
                    const SizedBox(height: 6),
                    Text(label,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400, fontSize: 11)),
                  ],
                ),
        ),
      );
}
