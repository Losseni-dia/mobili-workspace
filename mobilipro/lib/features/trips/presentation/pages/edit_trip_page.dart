import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../trips/presentation/pages/create_trip_page.dart'
    show ChauffeurItem, LegFare;
import '../../../trips/presentation/pages/trips_gare_page.dart';

/// Une ville de la liste (voir GET /trips/cities/by-country) — aligné sur CityOption (backend).
/// Dupliqué à dessein (voir create_trip_page.dart, covoiturage_trip_form_page.dart) : classe
/// privée non exportable entre fichiers Dart.
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

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _editChauffeursProvider = FutureProvider.autoDispose<List<ChauffeurItem>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<List<dynamic>>('/partenaire/chauffeurs');
  return (response.data ?? [])
      .map((e) => ChauffeurItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// Constantes — doit rester synchronisé avec VehicleType.java (backend)
// ─────────────────────────────────────────────────────────────────────────────

const _vehicleTypes = [
  'BUS_CLIMATISE',
  'BUS_CLASSIQUE',
  'CAR_70_PLACES',
  'MINIBUS',
  'MASSA_NORMAL',
  'MASSA_6_ROUES',
  'VAN',
  'SUV',
  'BERLINE',
  'CITADINE',
  'MONOSPACE',
  'PICKUP',
];

const _vehicleTypeLabels = {
  'BUS_CLIMATISE': 'Bus Climatisé',
  'BUS_CLASSIQUE': 'Bus Classique',
  'CAR_70_PLACES': 'Car 70 places',
  'MINIBUS': 'Minibus',
  'MASSA_NORMAL': 'Massa normal',
  'MASSA_6_ROUES': 'Massa 6 roues',
  'VAN': 'Van',
  'SUV': 'SUV',
  'BERLINE': 'Berline',
  'CITADINE': 'Citadine',
  'MONOSPACE': 'Monospace',
  'PICKUP': 'Pick-up',
};

class EditTripPage extends ConsumerStatefulWidget {
  const EditTripPage({super.key, required this.trip});
  final TripItem trip;

  @override
  ConsumerState<EditTripPage> createState() => _EditTripPageState();
}

class _EditTripPageState extends ConsumerState<EditTripPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _publishing = false;
  String? _error;
  // Sécurité "Enregistrer" / "Publier" : mis à jour localement après une publication
  // réussie pour désactiver le bouton sans avoir à quitter l'écran. Voir _publish().
  late String _status;

  // Itinéraire / véhicule
  late final TextEditingController _departureCityCtrl;
  late final TextEditingController _arrivalCityCtrl;
  late final TextEditingController _boardingPointCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _totalSeatsCtrl;
  late DateTime _departureDateTime;
  String _vehicleType = 'MASSA_NORMAL';
  File? _vehicleImage;
  int? _selectedChauffeurId;

  // Bagages
  bool _manageBagages = true;
  int _includedCabinBags = 1;
  int _includedHoldBags = 1;
  int _maxExtraHoldBags = 1;
  late final TextEditingController _extraHoldBagPriceCtrl;

  // Arrêts & tarifs par tronçon (Map key = 'fromIndex-toIndex')
  final List<String> _stopCities = [];
  final List<TextEditingController> _stopCtrlrs = [];
  final Map<String, TextEditingController> _legPriceCtrlrs = {};
  List<LegFare> _legFares = [];

  /// Autocomplétion ville — voir create_trip_page.dart (même pattern, dupliqué à dessein).
  int? _countryId;
  int? _departureCityId;
  int? _arrivalCityId;
  List<_CityOption> _departureSuggestions = [];
  List<_CityOption> _arrivalSuggestions = [];
  Timer? _departureDebounce;
  Timer? _arrivalDebounce;
  final List<int?> _stopCityIds = [];
  int? _activeStopIndex;
  List<_CityOption> _stopSuggestions = [];
  Timer? _stopDebounce;

  @override
  void initState() {
    super.initState();
    _loadCountryId();
    final t = widget.trip;
    _status = t.status;
    _departureCityCtrl = TextEditingController(text: t.departureCity);
    _arrivalCityCtrl = TextEditingController(text: t.arrivalCity);
    _boardingPointCtrl = TextEditingController(text: t.boardingPoint);
    _plateCtrl = TextEditingController(text: t.vehiculePlateNumber);
    _priceCtrl = TextEditingController(text: t.price.toStringAsFixed(0));
    _totalSeatsCtrl = TextEditingController(text: t.totalSeats.toString());
    _departureDateTime = t.departureDateTime;
    _vehicleType = _vehicleTypes.contains(t.vehicleType)
        ? t.vehicleType
        : _vehicleTypes.first;
    _selectedChauffeurId = t.assignedChauffeurId;

    _includedCabinBags = t.includedCabinBagsPerPassenger ?? 1;
    _includedHoldBags = t.includedHoldBagsPerPassenger ?? 1;
    _maxExtraHoldBags = t.maxExtraHoldBagsPerPassenger ?? 1;
    _extraHoldBagPriceCtrl = TextEditingController(
      text: (t.extraHoldBagPrice ?? 0).toStringAsFixed(0),
    );
    _manageBagages =
        (t.includedCabinBagsPerPassenger ?? 0) > 0 ||
        (t.includedHoldBagsPerPassenger ?? 0) > 0 ||
        (t.maxExtraHoldBagsPerPassenger ?? 0) > 0;

    _stopCities.addAll(
      (t.moreInfo ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty),
    );
    // Villes existantes chargées sans cityId connu (résolues par nom au prochain
    // enregistrement, voir TripService.resolveTripCity côté backend — même repli que les
    // formulaires web trip-edit/station-list).
    _stopCityIds.addAll(List<int?>.filled(_stopCities.length, null));
    for (final city in _stopCities) {
      _stopCtrlrs.add(TextEditingController(text: city));
    }
    _rebuildLegFares();
    _loadExistingLegFares();
  }

  @override
  void dispose() {
    _departureCityCtrl.dispose();
    _arrivalCityCtrl.dispose();
    _boardingPointCtrl.dispose();
    _plateCtrl.dispose();
    _priceCtrl.dispose();
    _totalSeatsCtrl.dispose();
    _extraHoldBagPriceCtrl.dispose();
    for (final c in _stopCtrlrs) {
      c.dispose();
    }
    for (final c in _legPriceCtrlrs.values) {
      c.dispose();
    }
    _departureDebounce?.cancel();
    _arrivalDebounce?.cancel();
    _stopDebounce?.cancel();
    super.dispose();
  }

  /// Résout l'id du pays "Côte d'Ivoire" une fois pour filtrer les recherches de ville — voir
  /// create_trip_page.dart (même pattern). Relance la recherche pour départ/arrivée si déjà
  /// saisis avant que cet appel réseau ait fini.
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
      if (_departureCityCtrl.text.trim().isNotEmpty && _departureCityId == null) {
        _onDepartureCityChanged(_departureCityCtrl.text);
      }
      if (_arrivalCityCtrl.text.trim().isNotEmpty && _arrivalCityId == null) {
        _onArrivalCityChanged(_arrivalCityCtrl.text);
      }
    } catch (_) {
      // Pas bloquant — l'autocomplétion reste simplement désactivée.
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
      return (res.data ?? []).cast<Map<String, dynamic>>().map(_CityOption.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  void _onDepartureCityChanged(String value) {
    setState(() => _departureCityId = null);
    _departureDebounce?.cancel();
    _departureDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _searchCities(value);
      if (mounted) setState(() => _departureSuggestions = results);
    });
  }

  void _onArrivalCityChanged(String value) {
    setState(() => _arrivalCityId = null);
    _arrivalDebounce?.cancel();
    _arrivalDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _searchCities(value);
      if (mounted) setState(() => _arrivalSuggestions = results);
    });
  }

  void _selectDepartureCity(_CityOption city) {
    setState(() {
      _departureCityCtrl.text = city.name;
      _departureCityId = city.id;
      _departureSuggestions = [];
    });
  }

  void _selectArrivalCity(_CityOption city) {
    setState(() {
      _arrivalCityCtrl.text = city.name;
      _arrivalCityId = city.id;
      _arrivalSuggestions = [];
    });
  }

  void _onStopCityChanged(int index, String value) {
    _activeStopIndex = index;
    if (index < _stopCityIds.length) {
      setState(() => _stopCityIds[index] = null);
    }
    _stopDebounce?.cancel();
    _stopDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _searchCities(value);
      if (mounted && _activeStopIndex == index) setState(() => _stopSuggestions = results);
    });
  }

  void _selectStopCity(int index, _CityOption city) {
    setState(() {
      if (index < _stopCityIds.length) _stopCityIds[index] = city.id;
      if (index < _stopCities.length) _stopCities[index] = city.name;
      if (index < _stopCtrlrs.length) _stopCtrlrs[index].text = city.name;
      _stopSuggestions = [];
      _rebuildLegFares();
    });
  }

  // ── Tronçons ───────────────────────────────────────────────────────────

  void _rebuildLegFares() {
    final allCities = [
      _departureCityCtrl.text.trim(),
      ..._stopCities,
      _arrivalCityCtrl.text.trim(),
    ];

    for (final c in _legPriceCtrlrs.values) {
      c.dispose();
    }
    _legPriceCtrlrs.clear();
    _legFares = [];

    // Départ/arrivée pas encore saisis : pas de combinaison bancale tant que le champ est vide.
    // Départ→arrivée déjà saisi via mainPriceCtrl ("Prix complet") dès qu'il y a un arrêt
    // intermédiaire — ne pas le redemander une 2ᵉ fois ici (voir create_trip_page.dart, même
    // logique, et add-trip.component.ts côté web).
    final last = allCities.length - 1;
    for (int i = 0; i < allCities.length - 1; i++) {
      if (allCities[i].isEmpty) continue;
      for (int j = i + 1; j < allCities.length; j++) {
        if (allCities[j].isEmpty) continue;
        if (i == 0 && j == last && last > 1) continue;
        final leg = LegFare(
          fromIndex: i,
          toIndex: j,
          fromCity: allCities[i],
          toCity: allCities[j],
        );
        _legFares.add(leg);
        _legPriceCtrlrs[leg.key] = TextEditingController();
      }
    }
  }

  Future<void> _loadExistingLegFares() async {
    try {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/trips/${widget.trip.id}',
      );
      final legFaresJson = res.data?['legFares'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        for (final item in legFaresJson) {
          final m = item as Map<String, dynamic>;
          final from = m['fromStopIndex'] as int;
          final to = m['toStopIndex'] as int;
          final price = (m['price'] as num).toDouble();
          _legPriceCtrlrs['$from-$to']?.text = price.toStringAsFixed(0);
        }
      });
    } catch (_) {
      // Silencieux : les tarifs par tronçon restent vides, modifiables à la main.
    }
  }

  void _addStop() {
    setState(() {
      _stopCities.add('');
      _stopCtrlrs.add(TextEditingController());
      _stopCityIds.add(null);
      _rebuildLegFares();
    });
  }

  void _removeStop(int index) {
    setState(() {
      _stopCities.removeAt(index);
      _stopCtrlrs.removeAt(index).dispose();
      if (index < _stopCityIds.length) _stopCityIds.removeAt(index);
      if (_activeStopIndex == index) {
        _activeStopIndex = null;
        _stopSuggestions = [];
      }
      _rebuildLegFares();
    });
  }

  // ── Véhicule ───────────────────────────────────────────────────────────

  Future<void> _pickVehicleImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _vehicleImage = File(picked.path));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.mobiliBlue),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureDateTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.mobiliBlue),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _departureDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ── Soumission ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final totalSeats = int.parse(_totalSeatsCtrl.text.trim());
      final price = double.parse(_priceCtrl.text.trim());
      final extraBagPrice =
          double.tryParse(_extraHoldBagPriceCtrl.text.trim()) ?? 0;

      final legFaresJson = <Map<String, dynamic>>[];
      for (final leg in _legFares) {
        final priceText = _legPriceCtrlrs[leg.key]?.text.trim() ?? '';
        if (priceText.isNotEmpty) {
          final p = double.tryParse(priceText);
          if (p != null && p >= 0) {
            legFaresJson.add({
              'fromStopIndex': leg.fromIndex,
              'toStopIndex': leg.toIndex,
              'price': p,
            });
          }
        }
      }

      final moreInfo = _stopCities.where((s) => s.trim().isNotEmpty).join(', ');

      // Ville choisie dans la liste (voir GET /trips/cities/by-country) — cityId prioritaire
      // côté backend, sinon repli sur le nom tapé (TripService.resolveTripCity, "ville
      // introuvable"). `stops` toujours envoyé (même vide) pour que le backend résolve aussi
      // départ/arrivée en vraies villes avec coordonnées — voir create_trip_page.dart, même
      // logique.
      final stopsJson = <Map<String, dynamic>>[];
      for (var i = 0; i < _stopCities.length; i++) {
        final name = _stopCities[i].trim();
        if (name.isEmpty) continue;
        stopsJson.add({
          'cityId': i < _stopCityIds.length ? _stopCityIds[i] : null,
          'cityName': name,
        });
      }

      final body = {
        'id': widget.trip.id,
        'partnerId': 0,
        'departureCity': _departureCityCtrl.text.trim(),
        'arrivalCity': _arrivalCityCtrl.text.trim(),
        'departureCityId': _departureCityId,
        'arrivalCityId': _arrivalCityId,
        'stops': stopsJson,
        'boardingPoint': _boardingPointCtrl.text.trim(),
        'vehiculePlateNumber': _plateCtrl.text.trim(),
        'vehicleType': _vehicleType,
        'departureDateTime': _departureDateTime.toIso8601String(),
        'price': price,
        'originDestinationPrice': price,
        'totalSeats': totalSeats,
        'availableSeats': widget.trip.availableSeats,
        'assignedChauffeurId': _selectedChauffeurId ?? 0,
        'moreInfo': moreInfo.isEmpty ? null : moreInfo,
        'legFares': legFaresJson,
        'includedCabinBagsPerPassenger': _manageBagages
            ? _includedCabinBags
            : 0,
        'includedHoldBagsPerPassenger': _manageBagages
            ? _includedHoldBags
            : 0,
        'maxExtraHoldBagsPerPassenger': _manageBagages
            ? _maxExtraHoldBags
            : 0,
        'extraHoldBagPrice': _manageBagages ? extraBagPrice : 0,
      };

      final formDataMap = <String, dynamic>{
        'trip': MultipartFile.fromString(
          jsonEncode(body),
          contentType: DioMediaType('application', 'json'),
        ),
      };

      if (_vehicleImage != null) {
        formDataMap['vehicleImage'] = await MultipartFile.fromFile(
          _vehicleImage!.path,
          contentType: DioMediaType('image', 'jpeg'),
        );
      }

      await ApiClient.instance.dio.put(
        '/trips/${widget.trip.id}',
        data: FormData.fromMap(formDataMap),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trajet modifié ✅'),
            backgroundColor: AppColors.stationGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Toujours brouillon après cette modification : ouvre directement sur l'onglet
        // "Brouillon" au retour, sinon le trajet enregistré n'apparaît sous aucun onglet
        // visible par défaut (EN_COURS) et semble avoir disparu.
        Navigator.of(context).pop(_status == 'DRAFT' ? 'DRAFT' : true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().contains('—')
            ? e.toString().split('—').last.trim()
            : 'Erreur lors de la modification';
        _loading = false;
      });
    }
  }

  Future<void> _publish() async {
    setState(() {
      _publishing = true;
      _error = null;
    });

    try {
      await ApiClient.instance.dio.post<void>(
        '/trips/${widget.trip.id}/publish',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trajet publié avec succès ! ✅'),
            backgroundColor: AppColors.stationGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Trajet fraîchement publié : ouvre directement sur l'onglet "Programmé" (trajet
        // actif) au lieu de rester bloqué sur le formulaire.
        Navigator.of(context).pop('PROGRAMMÉ');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().contains('—')
            ? e.toString().split('—').last.trim()
            : 'Erreur lors de la publication du trajet';
        _publishing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Modifier le trajet',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Route ──────────────────────────────────
            const _Section(label: 'Itinéraire'),
            _Field(
              controller: _departureCityCtrl,
              label: 'Ville de départ',
              icon: Icons.trip_origin_rounded,
              validator: _required,
              onChanged: _onDepartureCityChanged,
            ),
            if (_departureSuggestions.isNotEmpty)
              _CitySuggestionsList(suggestions: _departureSuggestions, onSelect: _selectDepartureCity)
            else if (_departureCityCtrl.text.trim().isNotEmpty && _departureCityId == null)
              const _CityNotFoundHint(),
            const SizedBox(height: 12),
            _Field(
              controller: _arrivalCityCtrl,
              label: 'Ville d\'arrivée',
              icon: Icons.location_on_rounded,
              validator: _required,
              onChanged: _onArrivalCityChanged,
            ),
            if (_arrivalSuggestions.isNotEmpty)
              _CitySuggestionsList(suggestions: _arrivalSuggestions, onSelect: _selectArrivalCity)
            else if (_arrivalCityCtrl.text.trim().isNotEmpty && _arrivalCityId == null)
              const _CityNotFoundHint(),
            const SizedBox(height: 12),
            _Field(
              controller: _boardingPointCtrl,
              label: 'Point d\'embarquement',
              icon: Icons.place_rounded,
              validator: _required,
            ),

            const SizedBox(height: 20),

            // ── Date / heure ───────────────────────────
            const _Section(label: 'Date et heure'),
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
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.mobiliBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat(
                          'dd/MM/yyyy à HH:mm',
                        ).format(_departureDateTime),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mobiliBlueDeep,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.edit_rounded,
                      color: AppColors.gray400,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Véhicule ───────────────────────────────
            const _Section(label: 'Véhicule'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _vehicleType,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.gray400,
                  ),
                  items: _vehicleTypes
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(_vehicleTypeLabels[v] ?? v),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _vehicleType = v!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _plateCtrl,
              label: 'Numéro de plaque',
              icon: Icons.confirmation_number_rounded,
              validator: _required,
            ),
            const SizedBox(height: 16),
            const _SectionLabel(label: 'Photo du véhicule (optionnel)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickVehicleImage,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _vehicleImage != null
                        ? AppColors.mobiliBlue
                        : AppColors.gray200,
                    width: _vehicleImage != null ? 2 : 1,
                  ),
                ),
                child: _vehicleImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _vehicleImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.directions_bus_rounded,
                            color: AppColors.gray300,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.trip.vehicleImageUrl != null
                                ? 'Photo actuelle conservée — appuyer pour changer'
                                : 'Appuyer pour ajouter une photo',
                            style: const TextStyle(
                              color: AppColors.gray400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Bagages ────────────────────────────────
            const _Section(label: 'Bagages'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _manageBagages
                      ? AppColors.mobiliBlue
                      : AppColors.gray200,
                  width: _manageBagages ? 2 : 1,
                ),
              ),
              child: SwitchListTile(
                value: _manageBagages,
                onChanged: (v) => setState(() => _manageBagages = v),
                activeThumbColor: AppColors.mobiliBlue,
                title: const Text(
                  'Gérer les bagages en ligne',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mobiliBlueDeep,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _manageBagages
                      ? 'Les passagers verront la politique bagages'
                      : 'Les bagages ne seront pas affichés',
                  style: const TextStyle(fontSize: 12, color: AppColors.gray400),
                ),
              ),
            ),
            if (_manageBagages) ...[
              const SizedBox(height: 16),
              _BagageCounter(
                icon: Icons.backpack_rounded,
                iconColor: AppColors.mobiliBlue,
                title: 'Bagages cabine inclus',
                subtitle: 'Sac à main, bagage à main',
                value: _includedCabinBags,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _includedCabinBags = v),
              ),
              const SizedBox(height: 12),
              _BagageCounter(
                icon: Icons.luggage_rounded,
                iconColor: AppColors.stationGreen,
                title: 'Valises soute incluses',
                subtitle: 'Bagages en soute, sans supplément',
                value: _includedHoldBags,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _includedHoldBags = v),
              ),
              const SizedBox(height: 12),
              _BagageCounter(
                icon: Icons.add_box_rounded,
                iconColor: AppColors.proGold,
                title: 'Max valises extra autorisées',
                subtitle: 'Par passager, en supplément',
                value: _maxExtraHoldBags,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _maxExtraHoldBags = v),
              ),
              if (_maxExtraHoldBags > 0) ...[
                const SizedBox(height: 12),
                _Field(
                  controller: _extraHoldBagPriceCtrl,
                  label: 'Prix par valise supplémentaire (FCFA)',
                  icon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
            ],

            const SizedBox(height: 20),

            // ── Chauffeur ──────────────────────────────
            const _Section(label: 'Chauffeur'),
            Consumer(
              builder: (context, ref, _) {
                final chauffeursAsync = ref.watch(_editChauffeursProvider);
                return chauffeursAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mobiliBlue,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  error: (e, _) => const Text(
                    'Impossible de charger les chauffeurs',
                    style: TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                  data: (chauffeurs) {
                    final knownIds = chauffeurs.map((c) => c.id).toSet();
                    final value =
                        _selectedChauffeurId != null &&
                            knownIds.contains(_selectedChauffeurId)
                        ? _selectedChauffeurId
                        : null;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: value,
                          isExpanded: true,
                          hint: const Text('Sans chauffeur assigné'),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.gray400,
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Sans chauffeur assigné'),
                            ),
                            ...chauffeurs.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.fullName),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedChauffeurId = v),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Tarif / places ─────────────────────────
            const _Section(label: 'Tarif et capacité'),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _priceCtrl,
                    label: 'Prix (FCFA)',
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Obligatoire';
                      if (double.tryParse(v.trim()) == null) {
                        return 'Nombre invalide';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: _totalSeatsCtrl,
                    label: 'Places totales',
                    icon: Icons.event_seat_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Obligatoire';
                      if (int.tryParse(v.trim()) == null) {
                        return 'Nombre invalide';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Villes desservies ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel(label: 'Villes desservies'),
                TextButton.icon(
                  onPressed: _addStop,
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: AppColors.mobiliBlue,
                  ),
                  label: const Text(
                    'Ajouter',
                    style: TextStyle(color: AppColors.mobiliBlue, fontSize: 13),
                  ),
                ),
              ],
            ),
            _StopTile(
              city: _departureCityCtrl.text.trim().isEmpty
                  ? 'Départ'
                  : _departureCityCtrl.text.trim(),
              isFixed: true,
            ),
            ...List.generate(
              _stopCities.length,
              (i) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StopTileEditable(
                    controller: _stopCtrlrs[i],
                    index: i + 1,
                    onRemove: () => _removeStop(i),
                    onChanged: (v) {
                      setState(() {
                        _stopCities[i] = v;
                        _rebuildLegFares();
                      });
                      _onStopCityChanged(i, v);
                    },
                  ),
                  if (_activeStopIndex == i && _stopSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 8),
                      child: _CitySuggestionsList(
                        suggestions: _stopSuggestions,
                        onSelect: (c) => _selectStopCity(i, c),
                      ),
                    ),
                ],
              ),
            ),
            _StopTile(
              city: _arrivalCityCtrl.text.trim().isEmpty
                  ? 'Arrivée'
                  : _arrivalCityCtrl.text.trim(),
              isFixed: true,
              isLast: true,
            ),

            if (_legFares.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionLabel(label: 'Prix par tronçon (optionnel)'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 14,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Définissez un prix pour chaque combinaison. Laissez vide pour le prorata.',
                        style: TextStyle(color: AppColors.warning, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._buildLegFareGroups(),
            ],

            const SizedBox(height: 32),

            // ── Boutons ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_loading || _publishing) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mobiliYellow,
                        foregroundColor: AppColors.mobiliBlueDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: AppColors.mobiliBlueDeep,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Enregistrer',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
                if (_status == 'DRAFT') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_loading || _publishing) ? null : _publish,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.stationGreen,
                          foregroundColor: AppColors.white,
                          disabledBackgroundColor: AppColors.gray200,
                          disabledForegroundColor: AppColors.gray400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _publishing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Publier',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLegFareGroups() {
    final widgets = <Widget>[];
    String? lastFrom;
    for (final leg in _legFares) {
      if (leg.fromCity != lastFrom) {
        lastFrom = leg.fromCity;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.mobiliBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Depuis ${leg.fromCity.isEmpty ? 'Stop ${leg.fromIndex}' : leg.fromCity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mobiliBlueDeep,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mobiliBlueFog,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: AppColors.mobiliBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          leg.toCity.isEmpty ? 'Stop ${leg.toIndex}' : leg.toCity,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mobiliBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _legPriceCtrlrs[leg.key],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Prix',
                    suffixText: 'F',
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.gray200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.gray200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.mobiliBlue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Obligatoire' : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.mobiliBlueDeep,
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.mobiliBlueDeep,
    ),
  );
}

/// Liste de suggestions sous le champ ville — voir create_trip_page.dart (même pattern,
/// dupliqué à dessein : pas de classe de base commune entre ces formulaires).
class _CitySuggestionsList extends StatelessWidget {
  const _CitySuggestionsList({required this.suggestions, required this.onSelect});

  final List<_CityOption> suggestions;
  final ValueChanged<_CityOption> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 6),
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
                          style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
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
        padding: EdgeInsets.only(top: 6, bottom: 6),
        child: Text(
          'Ville introuvable dans la liste — sera soumise telle quelle, en attente de validation admin.',
          style: TextStyle(fontSize: 11, color: AppColors.warning),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.onChanged,
  }) : maxLines = 1;
  final TextEditingController controller;
  final String label;
  final IconData icon;
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
      prefixIcon: Icon(icon, color: AppColors.gray400, size: 20),
      filled: true,
      fillColor: AppColors.white,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
  );
}

class _BagageCounter extends StatelessWidget {
  const _BagageCounter({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gray200),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.mobiliBlueDeep,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.gray400),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _CounterBtn(
              icon: Icons.remove_rounded,
              onTap: value > min ? () => onChanged(value - 1) : null,
            ),
            Container(
              width: 36,
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.mobiliBlueDeep,
                ),
              ),
            ),
            _CounterBtn(
              icon: Icons.add_rounded,
              onTap: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    ),
  );
}

class _CounterBtn extends StatelessWidget {
  const _CounterBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: onTap != null ? AppColors.mobiliBlueFog : AppColors.gray100,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 18,
        color: onTap != null ? AppColors.mobiliBlue : AppColors.gray300,
      ),
    ),
  );
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.city,
    this.isFixed = false,
    this.isLast = false,
  });
  final String city;
  final bool isFixed;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isLast ? AppColors.danger : AppColors.mobiliBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isLast ? Icons.location_on_rounded : Icons.trip_origin_rounded,
            color: AppColors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.mobiliBlueFog,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              city,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.mobiliBlue,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StopTileEditable extends StatelessWidget {
  const _StopTileEditable({
    required this.controller,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });
  final TextEditingController controller;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.gray300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Ville intermédiaire',
              hintStyle: const TextStyle(color: AppColors.gray300),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.mobiliBlue,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.remove_circle_rounded,
            color: AppColors.danger,
          ),
          onPressed: onRemove,
        ),
      ],
    ),
  );
}
