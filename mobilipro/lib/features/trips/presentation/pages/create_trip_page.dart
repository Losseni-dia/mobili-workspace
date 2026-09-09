import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';

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

// ─────────────────────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────────────────────

class ChauffeurItem {
  const ChauffeurItem({required this.id, required this.fullName});
  final int id;
  final String fullName;

  factory ChauffeurItem.fromJson(Map<String, dynamic> json) => ChauffeurItem(
    id: json['id'] as int,
    fullName: '${json['firstname'] ?? ''} ${json['lastname'] ?? ''}'.trim(),
  );
}

class LegFare {
  LegFare({
    required this.fromIndex,
    required this.toIndex,
    required this.fromCity,
    required this.toCity,
    this.price,
  });
  final int fromIndex;
  final int toIndex;
  final String fromCity;
  final String toCity;
  double? price;

  String get key => '$fromIndex-$toIndex';
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _chauffeursProvider = FutureProvider.autoDispose<List<ChauffeurItem>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<List<dynamic>>('/partenaire/chauffeurs');
  return (response.data ?? [])
      .map((e) => ChauffeurItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// Constantes
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

// ─────────────────────────────────────────────────────────────────────────────
// Page principale
// ─────────────────────────────────────────────────────────────────────────────

class CreateTripPage extends ConsumerStatefulWidget {
  const CreateTripPage({super.key});

  @override
  ConsumerState<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends ConsumerState<CreateTripPage> {
  final _pageCtrl = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;
  bool _isLoading = false;
  bool _isPublishing = false;
  String? _errorMessage;

  // Sécurité "Enregistrer" / "Publier" : le trajet est créé en brouillon (DRAFT, invisible
  // des voyageurs) au premier "Enregistrer" — _tripId renseigné dès lors. "Publier" ne
  // s'active qu'à partir de là, et rend le trajet réservable via POST /trips/{id}/publish.
  int? _tripId;

  // Étape 1
  final _departureCityCtrl = TextEditingController();
  final _arrivalCityCtrl = TextEditingController();
  final _boardingPointCtrl = TextEditingController();
  DateTime? _departureDateTime;

  // Étape 2
  String? _selectedVehicleType;
  final _plateCtrl = TextEditingController();
  final _totalSeatsCtrl = TextEditingController();
  File? _vehicleImage;

  // Étape 3
  bool _manageBagages = false;
  int _includedCabinBags = 1;
  int _includedHoldBags = 1;
  int _maxExtraHoldBags = 2;
  final _extraHoldBagPriceCtrl = TextEditingController(text: '2000');

  // Étape 4 — Map key = 'fromIndex-toIndex'
  final _mainPriceCtrl = TextEditingController();
  final List<String> _stopCities = [];
  final Map<String, TextEditingController> _legPriceCtrlrs = {};
  List<LegFare> _legFares = [];

  /// Autocomplétion ville (départ/arrivée/arrêts) — restreinte à la Côte d'Ivoire (même
  /// résolution que covoiturage_trip_form_page.dart : GET /trips/countries puis filtrage sur
  /// isoCode 'CI'). `*CityId` reste `null` tant qu'aucune suggestion n'a été choisie : repli
  /// "ville introuvable" (nom tapé soumis tel quel, voir CityLookupService côté backend).
  int? _countryId;
  int? _departureCityId;
  int? _arrivalCityId;
  List<_CityOption> _departureSuggestions = [];
  List<_CityOption> _arrivalSuggestions = [];
  Timer? _departureDebounce;
  Timer? _arrivalDebounce;

  /// Un id par entrée de `_stopCities` (même index) — `null` tant que la ville n'a pas été
  /// choisie dans la liste. Un seul champ actif à la fois pour les suggestions (comme les
  /// formulaires web add-trip/trip-edit).
  final List<int?> _stopCityIds = [];
  int? _activeStopIndex;
  List<_CityOption> _stopSuggestions = [];
  Timer? _stopDebounce;

  // Étape 5
  int? _selectedChauffeurId;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadCountryId();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _departureCityCtrl.dispose();
    _arrivalCityCtrl.dispose();
    _boardingPointCtrl.dispose();
    _plateCtrl.dispose();
    _totalSeatsCtrl.dispose();
    _extraHoldBagPriceCtrl.dispose();
    _mainPriceCtrl.dispose();
    for (final c in _legPriceCtrlrs.values) {
      c.dispose();
    }
    _departureDebounce?.cancel();
    _arrivalDebounce?.cancel();
    _stopDebounce?.cancel();
    super.dispose();
  }

  /// Résout l'id du pays "Côte d'Ivoire" une fois pour filtrer les recherches de ville — voir
  /// covoiturage_trip_form_page.dart (même pattern, dupliqué à dessein). Relance la recherche
  /// pour départ/arrivée si déjà saisis avant que cet appel réseau ait fini (sinon la recherche
  /// s'exécuterait avec _countryId encore null et ne se relancerait jamais toute seule).
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
      _stopSuggestions = [];
      _rebuildLegFares();
    });
  }

  void _rebuildLegFares() {
    final allCities = [
      _departureCityCtrl.text.trim(),
      ..._stopCities,
      _arrivalCityCtrl.text.trim(),
    ];

    // Dispose anciens controllers
    for (final c in _legPriceCtrlrs.values) {
      c.dispose();
    }
    _legPriceCtrlrs.clear();
    _legFares = [];

    // Génère TOUTES les combinaisons from→to (non-consécutives incluses)
    for (int i = 0; i < allCities.length - 1; i++) {
      for (int j = i + 1; j < allCities.length; j++) {
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

  void _addStop() => setState(() {
    _stopCities.add('');
    _stopCityIds.add(null);
  });

  void _removeStop(int index) {
    setState(() {
      _stopCities.removeAt(index);
      if (index < _stopCityIds.length) _stopCityIds.removeAt(index);
      if (_activeStopIndex == index) {
        _activeStopIndex = null;
        _stopSuggestions = [];
      }
      _rebuildLegFares();
    });
  }

  Future<void> _pickVehicleImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _vehicleImage = File(picked.path));
  }

  void _nextStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (!_step1Key.currentState!.validate()) return;
      if (_departureDateTime == null) {
        setState(
          () => _errorMessage = 'Sélectionnez la date et l\'heure de départ',
        );
        return;
      }
      _rebuildLegFares();
    }
    if (_currentStep == 1) {
      if (!_step2Key.currentState!.validate()) return;
      if (_selectedVehicleType == null) {
        setState(() => _errorMessage = 'Sélectionnez le type de véhicule');
        return;
      }
    }
    if (_currentStep == 3) {
      if (!_step4Key.currentState!.validate()) return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
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
      initialTime: const TimeOfDay(hour: 6, minute: 0),
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

  Future<void> _saveTrip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = ref.read(authProvider).valueOrNull?.profile;
      final totalSeats = int.tryParse(_totalSeatsCtrl.text.trim()) ?? 0;
      final mainPrice = double.tryParse(_mainPriceCtrl.text.trim()) ?? 0;
      final extraBagPrice =
          double.tryParse(_extraHoldBagPriceCtrl.text.trim()) ?? 0;

      // Construit legFares depuis toutes les combinaisons saisies
      final legFaresJson = <Map<String, dynamic>>[];
      for (final leg in _legFares) {
        final priceText = _legPriceCtrlrs[leg.key]?.text.trim() ?? '';
        if (priceText.isNotEmpty) {
          final price = double.tryParse(priceText);
          if (price != null && price >= 0) {
            legFaresJson.add({
              'fromStopIndex': leg.fromIndex,
              'toStopIndex': leg.toIndex,
              'price': price,
            });
          }
        }
      }

      final moreInfo = _stopCities.where((s) => s.isNotEmpty).join(', ');

      // Ville choisie dans la liste (voir GET /trips/cities/by-country) — cityId prioritaire
      // côté backend, sinon repli sur le nom tapé (TripService.resolveTripCity, "ville
      // introuvable"). `stops` toujours envoyé (même vide) pour que le backend résolve aussi
      // départ/arrivée en vraies villes avec coordonnées — voir add-trip.component.ts (web),
      // même logique.
      final stopsJson = <Map<String, dynamic>>[];
      for (var i = 0; i < _stopCities.length; i++) {
        final name = _stopCities[i].trim();
        if (name.isEmpty) continue;
        stopsJson.add({
          'cityId': i < _stopCityIds.length ? _stopCityIds[i] : null,
          'cityName': name,
        });
      }

      final tripMap = <String, dynamic>{
        if (_tripId != null) 'id': _tripId,
        'partnerId': profile?.id ?? 1,
        'departureCity': _departureCityCtrl.text.trim(),
        'arrivalCity': _arrivalCityCtrl.text.trim(),
        'departureCityId': _departureCityId,
        'arrivalCityId': _arrivalCityId,
        'stops': stopsJson,
        'boardingPoint': _boardingPointCtrl.text.trim(),
        'vehiculePlateNumber': _plateCtrl.text.trim(),
        'vehicleType': _selectedVehicleType,
        'transportType': 'PUBLIC',
        'departureDateTime': _departureDateTime!.toIso8601String().substring(
          0,
          16,
        ),
        'price': mainPrice,
        'originDestinationPrice': mainPrice,
        'totalSeats': totalSeats,
        'availableSeats': totalSeats,
        'includedCabinBagsPerPassenger': _manageBagages
            ? _includedCabinBags
            : 0,
        'includedHoldBagsPerPassenger': _manageBagages ? _includedHoldBags : 0,
        'maxExtraHoldBagsPerPassenger': _manageBagages ? _maxExtraHoldBags : 0,
        'extraHoldBagPrice': _manageBagages ? extraBagPrice : 0,
        if (moreInfo.isNotEmpty) 'moreInfo': moreInfo,
        if (legFaresJson.isNotEmpty) 'legFares': legFaresJson,
        if (_selectedChauffeurId != null)
          'assignedChauffeurId': _selectedChauffeurId,
      };

      final formDataMap = <String, dynamic>{
        'trip': MultipartFile.fromString(
          jsonEncode(tripMap),
          contentType: DioMediaType('application', 'json'),
        ),
      };

      if (_vehicleImage != null) {
        formDataMap['vehicleImage'] = await MultipartFile.fromFile(
          _vehicleImage!.path,
          contentType: DioMediaType('image', 'jpeg'),
        );
      }

      final response = _tripId == null
          ? await ApiClient.instance.dio.post<Map<String, dynamic>>(
              '/trips',
              data: FormData.fromMap(formDataMap),
            )
          : await ApiClient.instance.dio.put<Map<String, dynamic>>(
              '/trips/$_tripId',
              data: FormData.fromMap(formDataMap),
            );

      if (mounted) {
        setState(() {
          _tripId = response.data?['id'] as int? ?? _tripId;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trajet enregistré — vous pouvez maintenant le publier. ✅'),
            backgroundColor: AppColors.stationGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('—')
            ? e.toString().split('—').last.trim()
            : 'Erreur lors de l\'enregistrement du trajet';
        _isLoading = false;
      });
    }
  }

  Future<void> _publishTrip() async {
    if (_tripId == null) return;
    setState(() {
      _isPublishing = true;
      _errorMessage = null;
    });

    try {
      await ApiClient.instance.dio.post<void>('/trips/$_tripId/publish');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trajet publié avec succès ! ✅'),
            backgroundColor: AppColors.stationGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Trajet fraîchement publié : ouvre directement sur l'onglet "Programmé" (trajet
        // actif), pas de raison de laisser l'utilisateur chercher son trajet manuellement.
        Navigator.pop(context, 'PROGRAMMÉ');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('—')
            ? e.toString().split('—').last.trim()
            : 'Erreur lors de la publication du trajet';
        _isPublishing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = ['Trajet', 'Véhicule', 'Bagages', 'Prix', 'Chauffeur'];

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Nouveau trajet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          // Une fois le trajet enregistré (brouillon persisté côté serveur), reculer étape
          // par étape dans le wizard n'a plus d'intérêt — l'utilisateur veut sortir direct
          // vers sa liste de trajets, pas retraverser toute la configuration.
          // Trajet enregistré mais pas publié = brouillon : ouvre directement sur l'onglet
          // "Brouillon" au retour, sinon le trajet enregistré n'apparaît sous aucun onglet
          // visible par défaut (EN_COURS) et semble avoir disparu.
          onPressed: _tripId != null
              ? () => Navigator.pop(context, 'DRAFT')
              : (_currentStep > 0
                    ? _prevStep
                    : () => Navigator.pop(context)),
        ),
        actions: [
          if (_tripId != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'DRAFT'),
              icon: const Icon(Icons.list_alt_rounded, color: AppColors.white),
              label: const Text(
                'Mes trajets',
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: AppColors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.mobiliYellow,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: List.generate(_totalSteps * 2 - 1, (i) {
                if (i.isOdd) {
                  return _StepLine(active: _currentStep > i ~/ 2);
                }
                final step = i ~/ 2;
                return _StepDot(
                  step: step + 1,
                  current: _currentStep + 1,
                  label: stepLabels[step],
                );
              }),
            ),
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(
                  formKey: _step1Key,
                  departureCityCtrl: _departureCityCtrl,
                  arrivalCityCtrl: _arrivalCityCtrl,
                  boardingPointCtrl: _boardingPointCtrl,
                  departureDateTime: _departureDateTime,
                  onPickDateTime: _pickDateTime,
                  departureSuggestions: _departureSuggestions,
                  arrivalSuggestions: _arrivalSuggestions,
                  departureCityId: _departureCityId,
                  arrivalCityId: _arrivalCityId,
                  onDepartureCityChanged: _onDepartureCityChanged,
                  onArrivalCityChanged: _onArrivalCityChanged,
                  onSelectDepartureCity: _selectDepartureCity,
                  onSelectArrivalCity: _selectArrivalCity,
                ),
                _Step2(
                  formKey: _step2Key,
                  plateCtrl: _plateCtrl,
                  totalSeatsCtrl: _totalSeatsCtrl,
                  selectedVehicleType: _selectedVehicleType,
                  vehicleImage: _vehicleImage,
                  onVehicleTypeChanged: (v) =>
                      setState(() => _selectedVehicleType = v),
                  onPickImage: _pickVehicleImage,
                ),
                _Step3Bagages(
                  manageBagages: _manageBagages,
                  onManageBagagesChanged: (v) =>
                      setState(() => _manageBagages = v),
                  includedCabinBags: _includedCabinBags,
                  includedHoldBags: _includedHoldBags,
                  maxExtraHoldBags: _maxExtraHoldBags,
                  extraHoldBagPriceCtrl: _extraHoldBagPriceCtrl,
                  onCabinChanged: (v) => setState(() => _includedCabinBags = v),
                  onHoldChanged: (v) => setState(() => _includedHoldBags = v),
                  onMaxExtraChanged: (v) =>
                      setState(() => _maxExtraHoldBags = v),
                ),
                _Step4Prix(
                  formKey: _step4Key,
                  mainPriceCtrl: _mainPriceCtrl,
                  stopCities: _stopCities,
                  legFares: _legFares,
                  legPriceCtrlrs: _legPriceCtrlrs,
                  departureCity: _departureCityCtrl.text,
                  arrivalCity: _arrivalCityCtrl.text,
                  onAddStop: _addStop,
                  onRemoveStop: _removeStop,
                  onStopChanged: (index, value) {
                    setState(() {
                      _stopCities[index] = value;
                      _rebuildLegFares();
                    });
                    _onStopCityChanged(index, value);
                  },
                  activeStopIndex: _activeStopIndex,
                  stopSuggestions: _stopSuggestions,
                  onSelectStopCity: _selectStopCity,
                ),
                _Step5Chauffeur(
                  selectedChauffeurId: _selectedChauffeurId,
                  onChauffeurSelected: (id) =>
                      setState(() => _selectedChauffeurId = id),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _currentStep < _totalSteps - 1
                ? SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mobiliYellow,
                        foregroundColor: AppColors.mobiliBlueDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Suivant →',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: (_isLoading || _isPublishing)
                                ? null
                                : _saveTrip,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.mobiliBlueDeep,
                              side: const BorderSide(
                                color: AppColors.mobiliBlueDeep,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: AppColors.mobiliBlueDeep,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _tripId == null
                                        ? 'Enregistrer'
                                        : 'Enregistrer à nouveau',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            // Désactivé tant qu'aucun "Enregistrer" réussi n'a donné d'ID
                            // au trajet (brouillon DRAFT côté backend) — voir _tripId.
                            onPressed:
                                (_tripId == null || _isLoading || _isPublishing)
                                ? null
                                : _publishTrip,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.stationGreen,
                              foregroundColor: AppColors.white,
                              disabledBackgroundColor: AppColors.gray200,
                              disabledForegroundColor: AppColors.gray400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isPublishing
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
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Étape 1
// ─────────────────────────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  const _Step1({
    required this.formKey,
    required this.departureCityCtrl,
    required this.arrivalCityCtrl,
    required this.boardingPointCtrl,
    required this.departureDateTime,
    required this.onPickDateTime,
    required this.departureSuggestions,
    required this.arrivalSuggestions,
    required this.departureCityId,
    required this.arrivalCityId,
    required this.onDepartureCityChanged,
    required this.onArrivalCityChanged,
    required this.onSelectDepartureCity,
    required this.onSelectArrivalCity,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController departureCityCtrl;
  final TextEditingController arrivalCityCtrl;
  final TextEditingController boardingPointCtrl;
  final DateTime? departureDateTime;
  final VoidCallback onPickDateTime;
  final List<_CityOption> departureSuggestions;
  final List<_CityOption> arrivalSuggestions;
  final int? departureCityId;
  final int? arrivalCityId;
  final ValueChanged<String> onDepartureCityChanged;
  final ValueChanged<String> onArrivalCityChanged;
  final ValueChanged<_CityOption> onSelectDepartureCity;
  final ValueChanged<_CityOption> onSelectArrivalCity;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Informations du trajet'),
          const SizedBox(height: 12),
          _Field(
            controller: departureCityCtrl,
            label: 'Ville de départ',
            icon: Icons.trip_origin_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            onChanged: onDepartureCityChanged,
          ),
          if (departureSuggestions.isNotEmpty)
            _CitySuggestionsList(suggestions: departureSuggestions, onSelect: onSelectDepartureCity)
          else if (departureCityCtrl.text.trim().isNotEmpty && departureCityId == null)
            const _CityNotFoundHint(),
          const SizedBox(height: 12),
          _Field(
            controller: arrivalCityCtrl,
            label: 'Ville d\'arrivée',
            icon: Icons.location_on_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            onChanged: onArrivalCityChanged,
          ),
          if (arrivalSuggestions.isNotEmpty)
            _CitySuggestionsList(suggestions: arrivalSuggestions, onSelect: onSelectArrivalCity)
          else if (arrivalCityCtrl.text.trim().isNotEmpty && arrivalCityId == null)
            const _CityNotFoundHint(),
          const SizedBox(height: 12),
          _Field(
            controller: boardingPointCtrl,
            label: 'Point d\'embarquement',
            icon: Icons.pin_drop_rounded,
            hint: 'Ex: Gare routière d\'Adjamé',
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obligatoire' : null,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPickDateTime,
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
                    color: AppColors.gray400,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      departureDateTime == null
                          ? 'Date et heure de départ *'
                          : DateFormat(
                              'dd/MM/yyyy à HH:mm',
                            ).format(departureDateTime!),
                      style: TextStyle(
                        color: departureDateTime == null
                            ? AppColors.gray400
                            : AppColors.mobiliBlueDeep,
                        fontSize: 14,
                        fontWeight: departureDateTime == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.gray300,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Étape 2
// ─────────────────────────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  const _Step2({
    required this.formKey,
    required this.plateCtrl,
    required this.totalSeatsCtrl,
    required this.selectedVehicleType,
    required this.onVehicleTypeChanged,
    required this.vehicleImage,
    required this.onPickImage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController plateCtrl;
  final TextEditingController totalSeatsCtrl;
  final String? selectedVehicleType;
  final ValueChanged<String?> onVehicleTypeChanged;
  final File? vehicleImage;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Informations du véhicule'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedVehicleType,
                isExpanded: true,
                hint: const Text(
                  'Type de véhicule *',
                  style: TextStyle(color: AppColors.gray400),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.gray400,
                ),
                items: _vehicleTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(_vehicleTypeLabels[t] ?? t),
                      ),
                    )
                    .toList(),
                onChanged: onVehicleTypeChanged,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Field(
            controller: plateCtrl,
            label: 'Numéro de plaque',
            icon: Icons.confirmation_number_rounded,
            hint: 'Ex: AB 1234 CI',
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obligatoire' : null,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: totalSeatsCtrl,
            label: 'Nombre de places',
            icon: Icons.event_seat_rounded,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Obligatoire';
              if (int.tryParse(v.trim()) == null) return 'Nombre invalide';
              return null;
            },
          ),
          const SizedBox(height: 16),
          const _SectionLabel(label: 'Photo du véhicule (optionnel)'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: vehicleImage != null
                      ? AppColors.mobiliBlue
                      : AppColors.gray200,
                  width: vehicleImage != null ? 2 : 1,
                ),
              ),
              child: vehicleImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        vehicleImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_bus_rounded,
                          color: AppColors.gray300,
                          size: 40,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Appuyer pour ajouter une photo',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'JPG, PNG — optionnel',
                          style: TextStyle(
                            color: AppColors.gray300,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Étape 3 — Bagages
// ─────────────────────────────────────────────────────────────────────────────

class _Step3Bagages extends StatelessWidget {
  const _Step3Bagages({
    required this.manageBagages,
    required this.onManageBagagesChanged,
    required this.includedCabinBags,
    required this.includedHoldBags,
    required this.maxExtraHoldBags,
    required this.extraHoldBagPriceCtrl,
    required this.onCabinChanged,
    required this.onHoldChanged,
    required this.onMaxExtraChanged,
  });

  final bool manageBagages;
  final ValueChanged<bool> onManageBagagesChanged;
  final int includedCabinBags;
  final int includedHoldBags;
  final int maxExtraHoldBags;
  final TextEditingController extraHoldBagPriceCtrl;
  final ValueChanged<int> onCabinChanged;
  final ValueChanged<int> onHoldChanged;
  final ValueChanged<int> onMaxExtraChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'Gestion des bagages'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: manageBagages ? AppColors.mobiliBlue : AppColors.gray200,
              width: manageBagages ? 2 : 1,
            ),
          ),
          child: SwitchListTile(
            value: manageBagages,
            onChanged: onManageBagagesChanged,
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
              manageBagages
                  ? 'Les passagers verront la politique bagages'
                  : 'Les bagages ne seront pas affichés',
              style: const TextStyle(fontSize: 12, color: AppColors.gray400),
            ),
          ),
        ),
        if (manageBagages) ...[
          const SizedBox(height: 20),
          const _SectionLabel(label: 'Bagages inclus dans le billet'),
          const SizedBox(height: 16),
          _BagageCounter(
            icon: Icons.backpack_rounded,
            iconColor: AppColors.mobiliBlue,
            title: 'Bagages cabine inclus',
            subtitle: 'Sac à main, bagage à main',
            value: includedCabinBags,
            min: 0,
            max: 3,
            onChanged: onCabinChanged,
          ),
          const SizedBox(height: 12),
          _BagageCounter(
            icon: Icons.luggage_rounded,
            iconColor: AppColors.stationGreen,
            title: 'Valises soute incluses',
            subtitle: 'Bagages en soute, sans supplément',
            value: includedHoldBags,
            min: 0,
            max: 3,
            onChanged: onHoldChanged,
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.gray100),
          const SizedBox(height: 16),
          const _SectionLabel(label: 'Bagages supplémentaires'),
          const SizedBox(height: 16),
          _BagageCounter(
            icon: Icons.add_box_rounded,
            iconColor: AppColors.proGold,
            title: 'Max valises extra autorisées',
            subtitle: 'Par passager, en supplément',
            value: maxExtraHoldBags,
            min: 0,
            max: 5,
            onChanged: onMaxExtraChanged,
          ),
          if (maxExtraHoldBags > 0) ...[
            const SizedBox(height: 16),
            const _SectionLabel(label: 'Prix par valise supplémentaire'),
            const SizedBox(height: 8),
            _Field(
              controller: extraHoldBagPriceCtrl,
              label: 'Prix (FCFA)',
              icon: Icons.payments_rounded,
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mobiliBlueFog,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.mobiliBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.mobiliBlue,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Résumé politique bagages',
                      style: TextStyle(
                        color: AppColors.mobiliBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '✅ $includedCabinBags bagage(s) cabine inclus\n'
                  '✅ $includedHoldBags valise(s) soute incluse(s)\n'
                  '${maxExtraHoldBags > 0 ? '➕ Jusqu\'à $maxExtraHoldBags valise(s) extra à ${extraHoldBagPriceCtrl.text.isEmpty ? '?' : extraHoldBagPriceCtrl.text} FCFA/valise' : '❌ Aucun bagage extra autorisé'}',
                  style: const TextStyle(
                    color: AppColors.mobiliBlueDeep,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray200),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.luggage_outlined,
                  color: AppColors.gray400,
                  size: 32,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bagages non gérés en ligne',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Les passagers ne verront pas d\'information sur les bagages.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Étape 4 — Prix & tronçons (toutes combinaisons)
// ─────────────────────────────────────────────────────────────────────────────

class _Step4Prix extends StatefulWidget {
  const _Step4Prix({
    required this.formKey,
    required this.mainPriceCtrl,
    required this.stopCities,
    required this.legFares,
    required this.legPriceCtrlrs,
    required this.departureCity,
    required this.arrivalCity,
    required this.onAddStop,
    required this.onRemoveStop,
    required this.onStopChanged,
    required this.activeStopIndex,
    required this.stopSuggestions,
    required this.onSelectStopCity,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController mainPriceCtrl;
  final List<String> stopCities;
  final List<LegFare> legFares;
  final Map<String, TextEditingController> legPriceCtrlrs;
  final String departureCity;
  final String arrivalCity;
  final VoidCallback onAddStop;
  final ValueChanged<int> onRemoveStop;
  final void Function(int index, String value) onStopChanged;
  final int? activeStopIndex;
  final List<_CityOption> stopSuggestions;
  final void Function(int index, _CityOption city) onSelectStopCity;

  @override
  State<_Step4Prix> createState() => _Step4PrixState();
}

class _Step4PrixState extends State<_Step4Prix> {
  final List<TextEditingController> _stopCtrlrs = [];

  @override
  void didUpdateWidget(_Step4Prix old) {
    super.didUpdateWidget(old);
    while (_stopCtrlrs.length < widget.stopCities.length) {
      _stopCtrlrs.add(TextEditingController());
    }
    while (_stopCtrlrs.length > widget.stopCities.length) {
      _stopCtrlrs.last.dispose();
      _stopCtrlrs.removeLast();
    }
  }

  @override
  void dispose() {
    for (final c in _stopCtrlrs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Prix du trajet complet'),
          const SizedBox(height: 4),
          Text(
            '${widget.departureCity.isEmpty ? 'Départ' : widget.departureCity} → ${widget.arrivalCity.isEmpty ? 'Arrivée' : widget.arrivalCity}',
            style: const TextStyle(color: AppColors.gray500, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _Field(
            controller: widget.mainPriceCtrl,
            label: 'Prix complet (FCFA)',
            icon: Icons.payments_rounded,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Obligatoire';
              if (double.tryParse(v.trim()) == null) return 'Prix invalide';
              return null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel(label: 'Villes desservies'),
              TextButton.icon(
                onPressed: () {
                  while (_stopCtrlrs.length < widget.stopCities.length + 1) {
                    _stopCtrlrs.add(TextEditingController());
                  }
                  widget.onAddStop();
                },
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
            city: widget.departureCity.isEmpty
                ? 'Départ'
                : widget.departureCity,
            index: 0,
            isFixed: true,
          ),
          ...List.generate(widget.stopCities.length, (i) {
            if (_stopCtrlrs.length <= i) {
              _stopCtrlrs.add(
                TextEditingController(text: widget.stopCities[i]),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StopTileEditable(
                  controller: _stopCtrlrs[i],
                  index: i + 1,
                  onRemove: () => widget.onRemoveStop(i),
                  onChanged: (v) => widget.onStopChanged(i, v),
                ),
                if (widget.activeStopIndex == i && widget.stopSuggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: _CitySuggestionsList(
                      suggestions: widget.stopSuggestions,
                      onSelect: (c) {
                        _stopCtrlrs[i].text = c.name;
                        widget.onSelectStopCity(i, c);
                      },
                    ),
                  ),
              ],
            );
          }),
          _StopTile(
            city: widget.arrivalCity.isEmpty ? 'Arrivée' : widget.arrivalCity,
            index: widget.stopCities.length + 1,
            isFixed: true,
            isLast: true,
          ),

          if (widget.legFares.isNotEmpty) ...[
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

            // Groupement par ville de départ
            ...() {
              final widgets = <Widget>[];
              String? lastFrom;
              for (final leg in widget.legFares) {
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
                                    leg.toCity.isEmpty
                                        ? 'Stop ${leg.toIndex}'
                                        : leg.toCity,
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
                            controller: widget.legPriceCtrlrs[leg.key],
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
                                borderSide: const BorderSide(
                                  color: AppColors.gray200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.gray200,
                                ),
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
            }(),
          ],
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Étape 5 — Chauffeur
// ─────────────────────────────────────────────────────────────────────────────

class _Step5Chauffeur extends ConsumerWidget {
  const _Step5Chauffeur({
    required this.selectedChauffeurId,
    required this.onChauffeurSelected,
  });

  final int? selectedChauffeurId;
  final ValueChanged<int?> onChauffeurSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chauffeursAsync = ref.watch(_chauffeursProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Assigner un chauffeur'),
          const SizedBox(height: 4),
          const Text(
            'Optionnel — vous pouvez assigner plus tard.',
            style: TextStyle(color: AppColors.gray500, fontSize: 13),
          ),
          const SizedBox(height: 16),
          chauffeursAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.mobiliBlue),
            ),
            error: (e, _) => Text(
              'Erreur : $e',
              style: const TextStyle(color: AppColors.danger),
            ),
            data: (chauffeurs) => Column(
              children: [
                _ChauffeurTile(
                  name: 'Sans chauffeur assigné',
                  subtitle: 'À assigner ultérieurement',
                  isSelected: selectedChauffeurId == null,
                  onTap: () => onChauffeurSelected(null),
                  icon: Icons.person_off_rounded,
                ),
                const SizedBox(height: 8),
                if (chauffeurs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aucun chauffeur disponible.',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...chauffeurs.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ChauffeurTile(
                        name: c.fullName,
                        subtitle: 'Chauffeur #${c.id}',
                        isSelected: selectedChauffeurId == c.id,
                        onTap: () => onChauffeurSelected(c.id),
                        icon: Icons.person_rounded,
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

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helper
// ─────────────────────────────────────────────────────────────────────────────

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
    required this.index,
    this.isFixed = false,
    this.isLast = false,
  });
  final String city;
  final int index;
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

class _ChauffeurTile extends StatelessWidget {
  const _ChauffeurTile({
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.icon,
  });
  final String name;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.mobiliBlueFog : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.mobiliBlue : AppColors.gray200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.mobiliBlue : AppColors.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.white : AppColors.gray500,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.mobiliBlue
                        : AppColors.mobiliBlueDeep,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.mobiliBlue,
              size: 20,
            ),
        ],
      ),
    ),
  );
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.step,
    required this.current,
    required this.label,
  });
  final int step;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDone = current > step;
    final isActive = current == step;
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.stationGreen
                : isActive
                ? AppColors.mobiliBlue
                : AppColors.gray200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.white,
                    size: 13,
                  )
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? AppColors.white : AppColors.gray400,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: isActive ? AppColors.mobiliBlue : AppColors.gray400,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: active ? AppColors.mobiliBlue : AppColors.gray200,
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
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.mobiliBlueDeep,
    ),
  );
}

/// Liste de suggestions sous le champ ville — voir covoiturage_trip_form_page.dart (même
/// pattern, dupliqué à dessein : pas de classe de base commune entre ces formulaires).
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
        padding: EdgeInsets.only(top: 6),
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
    this.hint,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
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
