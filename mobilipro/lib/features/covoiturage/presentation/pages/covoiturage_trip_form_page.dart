import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

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

/// Création (`tripId == null`) ou édition (`tripId != null`) d'un trajet
/// covoiturage — `POST` / `PUT /covoiturage/trips`. Réservé aux conducteurs
/// covoiturage (`profile.isCovoiturageDriver`) ; jamais accessible à un
/// chauffeur compagnie classique.
class CovoiturageTripFormPage extends StatefulWidget {
  const CovoiturageTripFormPage({super.key, this.tripId});
  final int? tripId;

  @override
  State<CovoiturageTripFormPage> createState() => _CovoiturageTripFormPageState();
}

class _CovoiturageTripFormPageState extends State<CovoiturageTripFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _departureCtrl = TextEditingController();
  final _arrivalCtrl = TextEditingController();
  final _boardingPointCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _totalSeatsCtrl = TextEditingController(text: '3');
  final _moreInfoCtrl = TextEditingController();
  DateTime _departureDateTime = DateTime.now().add(const Duration(hours: 2));
  String _vehicleType = _vehicleTypes.first;
  File? _vehicleImage;

  bool get _isEditing => widget.tripId != null;
  bool _isLoadingTrip = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExistingTrip();
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

  Future<void> _loadExistingTrip() async {
    setState(() => _isLoadingTrip = true);
    try {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/trips/${widget.tripId}',
      );
      final data = res.data!;
      _departureCtrl.text = data['departureCity'] as String? ?? '';
      _arrivalCtrl.text = data['arrivalCity'] as String? ?? '';
      _boardingPointCtrl.text = data['boardingPoint'] as String? ?? '';
      _plateCtrl.text = data['vehiculePlateNumber'] as String? ?? '';
      _priceCtrl.text = ((data['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
      _totalSeatsCtrl.text = ((data['totalSeats'] as num?)?.toInt() ?? 1).toString();
      _moreInfoCtrl.text = data['moreInfo'] as String? ?? '';
      final dt = DateTime.tryParse(data['departureDateTime'] as String? ?? '');
      if (dt != null) _departureDateTime = dt;
      final vt = data['vehicleType'] as String?;
      if (vt != null && _vehicleTypes.contains(vt)) _vehicleType = vt;
    } catch (e) {
      _errorMessage = 'Impossible de charger le trajet : $e';
    } finally {
      if (mounted) setState(() => _isLoadingTrip = false);
    }
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
      _departureDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
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

      final formData = FormData.fromMap({
        'trip': MultipartFile.fromString(
          jsonEncode(tripData),
          contentType: DioMediaType('application', 'json'),
        ),
        if (_vehicleImage != null)
          'vehicleImage': await MultipartFile.fromFile(
            _vehicleImage!.path,
            filename: _vehicleImage!.path.split('/').last,
          ),
      });

      if (_isEditing) {
        await ApiClient.instance.dio.put<void>(
          '/covoiturage/trips/${widget.tripId}',
          data: formData,
        );
      } else {
        await ApiClient.instance.dio.post<void>('/covoiturage/trips', data: formData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Trajet modifié ✅' : 'Trajet publié ✅'),
            backgroundColor: AppColors.stationGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Text(_isEditing ? 'Modifier le trajet' : 'Publier un trajet',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoadingTrip
          ? const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const _SectionLabel(label: 'Itinéraire'),
                    const SizedBox(height: 12),
                    _Field(controller: _departureCtrl, label: 'Ville de départ', validator: _required),
                    const SizedBox(height: 12),
                    _Field(controller: _arrivalCtrl, label: 'Ville d\'arrivée', validator: _required),
                    const SizedBox(height: 12),
                    _Field(
                        controller: _boardingPointCtrl,
                        label: 'Point de rendez-vous',
                        validator: _required),
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
                            const Icon(Icons.calendar_today_rounded,
                                size: 18, color: AppColors.mobiliBlue),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('dd/MM/yyyy à HH:mm').format(_departureDateTime),
                              style: const TextStyle(
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
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(_vehicleTypeLabels[v] ?? v)))
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
                                child: Image.file(_vehicleImage!,
                                    fit: BoxFit.cover, width: double.infinity),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.directions_car_rounded,
                                      color: AppColors.gray300, size: 28),
                                  SizedBox(height: 6),
                                  Text(
                                    'Photo du véhicule (optionnel — sinon celle de votre profil)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.gray400, fontSize: 11),
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

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mobiliYellow,
                          foregroundColor: AppColors.mobiliBlueDeep,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(color: AppColors.mobiliBlueDeep, strokeWidth: 2),
                              )
                            : Text(
                                _isEditing ? 'Enregistrer les modifications' : 'Publier le trajet',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
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
              style: const TextStyle(
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
