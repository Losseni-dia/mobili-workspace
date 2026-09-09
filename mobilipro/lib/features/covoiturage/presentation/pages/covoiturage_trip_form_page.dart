import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

/// Une ville de la liste (voir GET /trips/cities/by-country) — aligné sur CityOption (backend).
class _CityOption {
  const _CityOption({required this.id, required this.name, required this.verified});
  final int id;
  final String name;
  final bool verified;

  factory _CityOption.fromJson(Map<String, dynamic> j) => _CityOption(
        id: j['id'] as int,
        name: j['name'] as String,
        verified: j['verified'] as bool? ?? true,
      );
}

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

  /// Autocomplétion ville — restreinte à la Côte d'Ivoire (les conducteurs covoiturage
  /// particuliers de cette app y sont tous rattachés ; pas de notion de "pays de la société"
  /// pour un compte individuel, contrairement au flux gares/société web). `*CityId` reste `null`
  /// tant qu'aucune suggestion n'a été choisie : dans ce cas le nom tapé est soumis tel quel,
  /// exactement comme avant ce changement (aucune régression sur le texte libre).
  int? _countryId;
  int? _departureCityId;
  int? _arrivalCityId;
  List<_CityOption> _departureSuggestions = [];
  List<_CityOption> _arrivalSuggestions = [];
  Timer? _departureDebounce;
  Timer? _arrivalDebounce;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExistingTrip();
    _loadCountryId();
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
    _departureDebounce?.cancel();
    _arrivalDebounce?.cancel();
    super.dispose();
  }

  /// Résout l'id du pays "Côte d'Ivoire" une fois pour filtrer les recherches de ville — en cas
  /// d'échec (réseau, pays introuvable), l'autocomplétion reste simplement désactivée et les
  /// champs se comportent comme avant (texte libre), jamais bloquant.
  ///
  /// Relance la recherche pour un champ déjà rempli une fois l'id chargé : sans ça, si
  /// l'utilisateur tape avant la fin de cet appel réseau, `_searchCities` s'exécute avec
  /// `_countryId == null` et ne se relance jamais toute seule — la ville tapée reste "introuvable"
  /// indéfiniment même si elle existe, tant qu'on ne retape pas une lettre (bug constaté en test).
  Future<void> _loadCountryId() async {
    try {
      final res = await ApiClient.instance.dio.get<List<dynamic>>('/trips/countries');
      final countries = res.data ?? [];
      final ci = countries.cast<Map<String, dynamic>>().firstWhere(
            (c) => c['isoCode'] == 'CI',
            orElse: () => const {},
          );
      final id = ci['id'] as int?;
      if (!mounted || id == null) return;
      setState(() => _countryId = id);
      if (_departureCtrl.text.trim().isNotEmpty && _departureCityId == null) {
        _onDepartureChanged(_departureCtrl.text);
      }
      if (_arrivalCtrl.text.trim().isNotEmpty && _arrivalCityId == null) {
        _onArrivalChanged(_arrivalCtrl.text);
      }
    } catch (_) {
      // Pas bloquant — voir Javadoc de la méthode.
    }
  }

  Future<List<_CityOption>> _searchCities(String query) async {
    final countryId = _countryId;
    if (countryId == null || query.trim().isEmpty) return [];
    try {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/trips/cities/by-country',
        queryParameters: {'countryId': countryId, 'q': query.trim()},
      );
      return (res.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(_CityOption.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _onDepartureChanged(String value) {
    setState(() => _departureCityId = null);
    _departureDebounce?.cancel();
    _departureDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _searchCities(value);
      if (mounted) setState(() => _departureSuggestions = results);
    });
  }

  void _onArrivalChanged(String value) {
    setState(() => _arrivalCityId = null);
    _arrivalDebounce?.cancel();
    _arrivalDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _searchCities(value);
      if (mounted) setState(() => _arrivalSuggestions = results);
    });
  }

  void _selectDepartureCity(_CityOption city) {
    setState(() {
      _departureCtrl.text = city.name;
      _departureCityId = city.id;
      _departureSuggestions = [];
    });
  }

  void _selectArrivalCity(_CityOption city) {
    setState(() {
      _arrivalCtrl.text = city.name;
      _arrivalCityId = city.id;
      _arrivalSuggestions = [];
    });
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
        // Ville choisie dans la liste (voir GET /trips/cities/by-country) — cityId prioritaire
        // côté backend, sinon repli sur le nom tapé tel quel (comportement historique inchangé).
        if (_departureCityId != null) 'departureCityId': _departureCityId,
        if (_arrivalCityId != null) 'arrivalCityId': _arrivalCityId,
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
                    _Field(
                      controller: _departureCtrl,
                      label: 'Ville de départ',
                      validator: _required,
                      onChanged: _onDepartureChanged,
                    ),
                    if (_departureSuggestions.isNotEmpty)
                      _CitySuggestionsList(
                        suggestions: _departureSuggestions,
                        onSelect: _selectDepartureCity,
                      )
                    else if (_departureCtrl.text.trim().isNotEmpty && _departureCityId == null)
                      const _CityNotFoundHint(),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _arrivalCtrl,
                      label: 'Ville d\'arrivée',
                      validator: _required,
                      onChanged: _onArrivalChanged,
                    ),
                    if (_arrivalSuggestions.isNotEmpty)
                      _CitySuggestionsList(
                        suggestions: _arrivalSuggestions,
                        onSelect: _selectArrivalCity,
                      )
                    else if (_arrivalCtrl.text.trim().isNotEmpty && _arrivalCityId == null)
                      const _CityNotFoundHint(),
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

/// Liste de suggestions sous le champ ville (jamais un overlay flottant, cohérent avec le style
/// simple des autres pages de cette app) — un tap remplit le champ et mémorise l'id choisi.
class _CitySuggestionsList extends StatelessWidget {
  const _CitySuggestionsList({required this.suggestions, required this.onSelect});

  final List<_CityOption> suggestions;
  final ValueChanged<_CityOption> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6),
        constraints: const BoxConstraints(maxHeight: 180),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray200),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: suggestions.length,
          itemBuilder: (_, i) {
            final city = suggestions[i];
            return InkWell(
              onTap: () => onSelect(city),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.mobiliBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(city.name, style: const TextStyle(color: AppColors.mobiliBlueDeep)),
                    ),
                    if (!city.verified)
                      const Text('non vérifiée',
                          style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

/// Message affiché quand aucune suggestion ne correspond au texte tapé — la saisie reste
/// acceptée telle quelle (repli "ville introuvable", voir CityLookupService côté backend).
class _CityNotFoundHint extends StatelessWidget {
  const _CityNotFoundHint();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text(
          'Ville introuvable dans la liste — sera soumise telle quelle, en attente de validation admin.',
          style: TextStyle(fontSize: 11, color: Colors.orange),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
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
