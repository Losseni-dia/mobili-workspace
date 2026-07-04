import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobili/shared/widgets/private_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_error_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/covoiturage_provider.dart';

/// Édition du profil conducteur (véhicule + photos) — `PUT /covoiturage/profile`.
///
/// Le statut KYC et les documents d'identité ne sont pas modifiables ici :
/// seul un administrateur peut y toucher.
class CovoiturageProfilePage extends ConsumerStatefulWidget {
  const CovoiturageProfilePage({super.key});

  @override
  ConsumerState<CovoiturageProfilePage> createState() =>
      _CovoiturageProfilePageState();
}

class _CovoiturageProfilePageState
    extends ConsumerState<CovoiturageProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brandCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _greyCardCtrl;
  File? _driverPhoto;
  File? _vehiclePhoto;
  bool _initialized = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _greyCardCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile() {
    final profile = ref.read(currentProfileProvider);
    _brandCtrl = TextEditingController(text: profile?.covoiturageVehicleBrand ?? '');
    _plateCtrl = TextEditingController(text: profile?.covoiturageVehiclePlate ?? '');
    _colorCtrl = TextEditingController(text: profile?.covoiturageVehicleColor ?? '');
    _greyCardCtrl =
        TextEditingController(text: profile?.covoiturageGreyCardNumber ?? '');
    _initialized = true;
  }

  Future<void> _pickPhoto(void Function(File) onPicked) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) onPicked(File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(covoiturageProfileNotifierProvider.notifier).save(
          vehicleBrand: _brandCtrl.text.trim(),
          vehiclePlate: _plateCtrl.text.trim(),
          vehicleColor: _colorCtrl.text.trim(),
          greyCardNumber: _greyCardCtrl.text.trim(),
          driverPhoto: _driverPhoto,
          vehiclePhoto: _vehiclePhoto,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour ✅'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) _initFromProfile();
    final profile = ref.watch(currentProfileProvider);
    final saveState = ref.watch(covoiturageProfileNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
     appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        title: const Text('Mon profil conducteur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (saveState.status == CovoiturageProfileSaveStatus.error &&
                  saveState.errorMessage != null) ...[
                MobiliErrorBanner(message: saveState.errorMessage!),
                const SizedBox(height: 16),
              ],

              const Text('PHOTOS',
                  style: TextStyle(
                    color: AppColors.mobiliBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1,
                  )),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PhotoTile(
                      label: 'Vous',
                      file: _driverPhoto,
                      existingUrl: profile?.covoiturageDriverPhotoUrl,
                      onPick: () => _pickPhoto((f) => setState(() => _driverPhoto = f)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PhotoTile(
                      label: 'Véhicule',
                      file: _vehiclePhoto,
                      existingUrl: profile?.covoiturageVehiclePhotoUrl,
                      onPick: () => _pickPhoto((f) => setState(() => _vehiclePhoto = f)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text('VÉHICULE',
                  style: TextStyle(
                    color: AppColors.mobiliBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1,
                  )),
              const SizedBox(height: 12),
              _Field(controller: _brandCtrl, label: 'Marque'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Field(controller: _plateCtrl, label: 'Plaque')),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(controller: _colorCtrl, label: 'Couleur')),
                ],
              ),
              const SizedBox(height: 12),
              _Field(controller: _greyCardCtrl, label: 'Numéro de carte grise'),
              const SizedBox(height: 28),

              MobiliButton(
                label: 'Enregistrer',
                isLoading: saveState.isSaving,
                onPressed: saveState.isSaving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: (v) =>
            v == null || v.trim().isEmpty ? '$label requis(e).' : null,
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.label,
    required this.file,
    required this.existingUrl,
    required this.onPick,
  });

  final String label;
  final File? file;
  final String? existingUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    // Les photos covoiturage sont des médias privés (JWT requis pour les lire
    // via /media/private?rel=...) : Image.network ne peut pas porter ce
    // header simplement, donc on n'affiche un aperçu que pour un fichier
    // tout juste sélectionné localement, et un simple indicatif sinon.
   // Priorité : photo tout juste sélectionnée localement > photo déjà
    // enregistrée côté serveur (URL publique /uploads/..., même pattern que
    // _DriverCard sur le dashboard) > aucun aperçu.
    Widget? preview;
    if (file != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(file!, fit: BoxFit.cover, width: double.infinity),
      );
    } else if (existingUrl != null) {
      final url = existingUrl!;
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PrivateNetworkImage(
          relativePath: url,
          fit: BoxFit.cover,
          errorWidget: Center(
            child: Icon(Icons.check_circle_outline_rounded,
                color: AppColors.stationGreen, size: 26),
          ),
        ),
      );
    }

    return GestureDetector(
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
        child: preview ??
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  existingUrl != null
                      ? Icons.check_circle_outline_rounded
                      : Icons.add_a_photo_outlined,
                  color: existingUrl != null
                      ? AppColors.stationGreen
                      : AppColors.gray300,
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  existingUrl != null ? '$label : enregistrée' : label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.gray400, fontSize: 11),
                ),
                if (existingUrl != null)
                  Text('Toucher pour changer',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.mobiliBlue, fontSize: 10)),
              ],
            ),
      ),
    );
  }
}
