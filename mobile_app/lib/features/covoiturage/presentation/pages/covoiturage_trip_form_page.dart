import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_error_widget.dart';
import '../../../trips/domain/models/trip.dart';
import '../../providers/covoiturage_provider.dart';

/// Types de véhicule pertinents pour un conducteur particulier (cf.
/// VehicleType.java côté backend — sous-ensemble personnel, hors flotte pro).
const _vehicleTypes = ['SUV', 'BERLINE', 'CITADINE', 'MONOSPACE', 'PICKUP'];

const _vehicleTypeLabels = {
  'SUV': 'SUV',
  'BERLINE': 'Berline',
  'CITADINE': 'Citadine',
  'MONOSPACE': 'Monospace',
  'PICKUP': 'Pick-up',
};

/// Création (`trip == null`) ou édition (`trip != null`) d'un trajet
/// covoiturage — `POST` / `PUT /covoiturage/trips`.
class CovoiturageTripFormPage extends ConsumerStatefulWidget {
  const CovoiturageTripFormPage({super.key, this.trip});
  final Trip? trip;

  @override
  ConsumerState<CovoiturageTripFormPage> createState() =>
      _CovoiturageTripFormPageState();
}

class _CovoiturageTripFormPageState
    extends ConsumerState<CovoiturageTripFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _departureCtrl;
  late final TextEditingController _arrivalCtrl;
  late final TextEditingController _boardingPointCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _totalSeatsCtrl;
  late final TextEditingController _moreInfoCtrl;
  late DateTime _departureDateTime;
  late String _vehicleType;
  File? _vehicleImage;

  bool get _isEditing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    _departureCtrl = TextEditingController(text: t?.departureCity ?? '');
    _arrivalCtrl = TextEditingController(text: t?.arrivalCity ?? '');
    _boardingPointCtrl = TextEditingController(text: t?.boardingPoint ?? '');
    _plateCtrl = TextEditingController();
    _priceCtrl = TextEditingController(text: t != null ? t.priceXof.toStringAsFixed(0) : '');
    _totalSeatsCtrl = TextEditingController(text: t?.totalSeats.toString() ?? '3');
    _moreInfoCtrl = TextEditingController(text: t?.moreInfo ?? '');
    _departureDateTime = t?.departureTime ?? DateTime.now().add(const Duration(hours: 2));
    _vehicleType = _vehicleTypes.contains(t?.vehicleType) ? t!.vehicleType! : _vehicleTypes.first;
  }

  @override
  void dispose() {
    _departureCtrl.dispose();
    _arrivalCtrl.dispose();
    _boardingPointCtrl.dispose();
    _plateCtrl.dispose();
    _priceCtrl.dispose();
    _totalSeatsCtrl.dispose();
    _moreInfoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureDateTime),
    );
    if (time == null) return;
    setState(() {
      _departureDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickVehicleImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _vehicleImage = File(picked.path));
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Obligatoire' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final tripData = <String, dynamic>{
      'departureCity': _departureCtrl.text.trim(),
      'arrivalCity': _arrivalCtrl.text.trim(),
      'boardingPoint': _boardingPointCtrl.text.trim(),
      'vehicleType': _vehicleType,
      'departureDateTime': _departureDateTime.toIso8601String(),
      'price': double.parse(_priceCtrl.text.trim()),
      'totalSeats': int.parse(_totalSeatsCtrl.text.trim()),
      if (_plateCtrl.text.trim().isNotEmpty) 'vehiculePlateNumber': _plateCtrl.text.trim(),
      if (_moreInfoCtrl.text.trim().isNotEmpty) 'moreInfo': _moreInfoCtrl.text.trim(),
    };

    final notifier = ref.read(covoiturageTripNotifierProvider.notifier);
    final ok = _isEditing
        ? await notifier.update(id: widget.trip!.id, tripData: tripData, vehicleImage: _vehicleImage)
        : await notifier.create(tripData: tripData, vehicleImage: _vehicleImage);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Trajet modifié ✅' : 'Trajet publié ✅'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(covoiturageTripNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
     appBar: MobiliAppBar(
        title: _isEditing ? 'Modifier le trajet' : 'Publier un trajet',
        showBackButton: true,
        titleFontSize: 18,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (saveState.status == CovoiturageTripSaveStatus.error &&
                  saveState.errorMessage != null) ...[
                MobiliErrorBanner(message: saveState.errorMessage!),
                const SizedBox(height: 16),
              ],

              const _SectionLabel(label: 'Itinéraire'),
              const SizedBox(height: 12),
              _Field(controller: _departureCtrl, label: 'Ville de départ', validator: _required),
              const SizedBox(height: 12),
              _Field(controller: _arrivalCtrl, label: 'Ville d\'arrivée', validator: _required),
              const SizedBox(height: 12),
              _Field(controller: _boardingPointCtrl, label: 'Point de rendez-vous', validator: _required),
              const SizedBox(height: 12),
              _Field(
                controller: _moreInfoCtrl,
                label: 'Villes traversées (séparées par virgule, optionnel)',
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              const _SectionLabel(label: 'Date et heure'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.mobiliBlue),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd/MM/yyyy à HH:mm').format(_departureDateTime),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.mobiliBlueDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const _SectionLabel(label: 'Véhicule'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _vehicleType,
                    isExpanded: true,
                    items: _vehicleTypes
                        .map((v) => DropdownMenuItem(value: v, child: Text(_vehicleTypeLabels[v] ?? v)))
                        .toList(),
                    onChanged: (v) => setState(() => _vehicleType = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _plateCtrl,
                label: 'Plaque (laisser vide = celle de votre profil)',
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickVehicleImage,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _vehicleImage != null ? AppColors.mobiliBlue : AppColors.gray200,
                      width: _vehicleImage != null ? 2 : 1,
                    ),
                  ),
                  child: _vehicleImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_vehicleImage!, fit: BoxFit.cover, width: double.infinity),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.directions_car_rounded, color: AppColors.gray300, size: 28),
                            const SizedBox(height: 6),
                            Text(
                              'Photo du véhicule (optionnel — sinon celle de votre profil)',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400, fontSize: 11),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              const _SectionLabel(label: 'Tarif et places'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _priceCtrl,
                      label: 'Prix par place (FCFA)',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obligatoire';
                        if (double.tryParse(v.trim()) == null) return 'Nombre invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _totalSeatsCtrl,
                      label: 'Places proposées',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obligatoire';
                        if (int.tryParse(v.trim()) == null) return 'Nombre invalide';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              MobiliButton(
                label: _isEditing ? 'Enregistrer les modifications' : 'Publier le trajet',
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
  const _Field({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
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
