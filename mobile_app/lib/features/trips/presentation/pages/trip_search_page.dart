import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobili/shared/widgets/city_autocomplete_field.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/mobili_app_bar.dart';
import '../../../../shared/widgets/mobili_error_widget.dart';
import '../../../../shared/widgets/mobili_loader.dart';
import '../../providers/trip_provider.dart';
import 'trip_detail_page.dart';

class TripSearchPage extends ConsumerStatefulWidget {
  const TripSearchPage({super.key});

  @override
  ConsumerState<TripSearchPage> createState() => _TripSearchPageState();
}

class _TripSearchPageState extends ConsumerState<TripSearchPage> {
  final _departureCtrl = TextEditingController();
  final _arrivalCtrl = TextEditingController();
  DateTime? _selectedDate;
  String? _transportType;

  @override
  void initState() {
    super.initState();
    // Filtre instantané : chaque frappe met à jour la recherche directement,
    // sans bouton — même comportement que la page d'accueil. Comme
    // TextEditingController.clear() (le bouton "X") notifie aussi les
    // listeners, cliquer sur la croix déclenche également ce filtre.
    _departureCtrl.addListener(_updateSearch);
    _arrivalCtrl.addListener(_updateSearch);
  }

  @override
  void dispose() {
    _departureCtrl.removeListener(_updateSearch);
    _arrivalCtrl.removeListener(_updateSearch);
    _departureCtrl.dispose();
    _arrivalCtrl.dispose();
    super.dispose();
  }

  void _updateSearch() {
    ref.read(tripSearchParamsProvider.notifier).state = TripSearchParams(
      departure: _departureCtrl.text.trim().isEmpty
          ? null
          : _departureCtrl.text.trim(),
      arrival:
          _arrivalCtrl.text.trim().isEmpty ? null : _arrivalCtrl.text.trim(),
      date: _selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
          : null,
      transportType: _transportType,
    );
  }

  void _clearSearch() {
    _departureCtrl.clear();
    _arrivalCtrl.clear();
    setState(() {
      _selectedDate = null;
      _transportType = null;
    });
    ref.read(tripSearchParamsProvider.notifier).state =
        const TripSearchParams();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripsAsync = ref.watch(tripsProvider);
    final searchParams = ref.watch(tripSearchParamsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.mobiliYellowPale,
      appBar: MobiliAppBar(
        title: 'Trouver un trajet',
         backRoute: '/',
        showBackButton: true,
        actions: [
          if (!searchParams.isEmpty)
            TextButton(
              onPressed: _clearSearch,
              style: TextButton.styleFrom(foregroundColor: AppColors.white),
              child: const Text('Effacer'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Formulaire de recherche stylé Mobili
          Container(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                 Expanded(
                      child: CityAutocompleteField(
                        controller: _departureCtrl,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                        decoration: const InputDecoration(
                          labelText: 'Départ',
                          hintText: 'Abidjan',
                          prefixIcon: Icon(Icons.trip_origin, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CityAutocompleteField(
                        controller: _arrivalCtrl,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                        decoration: const InputDecoration(
                          labelText: 'Arrivée',
                          hintText: 'Bouaké',
                          prefixIcon: Icon(Icons.place_outlined, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? now,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            _updateSearch();
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18),
                            fillColor: isDark
                                ? AppColors.darkSurfaceRaised
                                : AppColors.gray50,
                            suffixIcon: _selectedDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 16),
                                    onPressed: () {
                                      setState(() => _selectedDate = null);
                                      _updateSearch();
                                    },
                                  )
                                : null,
                          ),
                          child: Text(
                            _selectedDate != null
                                ? DateFormat('dd/MM/yyyy')
                                    .format(_selectedDate!)
                                : 'Choisir une date',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _transportType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          prefixIcon: const Icon(Icons.directions_bus_outlined,
                              size: 18),
                          fillColor: isDark
                              ? AppColors.darkSurfaceRaised
                              : AppColors.gray50,
                        ),
                        // Valeurs alignées sur le backend (mêmes que l'accueil) —
                        // BUS/MINIBUS ne correspondaient à aucun enum attendu et
                        // ne filtraient donc jamais correctement.
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tous')),
                          DropdownMenuItem(
                              value: 'PUBLIC', child: Text('Public')),
                          DropdownMenuItem(
                              value: 'COVOITURAGE', child: Text('Covoiturage')),
                        ],
                        onChanged: (v) {
                          setState(() => _transportType = v);
                          _updateSearch();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Section Résultats
          Expanded(
            child: tripsAsync.when(
              loading: () => const MobiliSkeletonList(count: 4),
              error: (err, _) => MobiliErrorWidget(
                error:
                    MobiliErrorData(errorCode: 'NET', message: err.toString()),
                onRetry: () => ref.invalidate(tripsProvider),
              ),
              data: (trips) {
                if (trips.isEmpty) {
                  return const EmptyStateWidget(type: MobiliEmptyType.trips);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(tripServiceProvider).invalidateCache();
                    ref.invalidate(tripsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) =>
                        _TripCard(trip: trips[i], isDark: isDark),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.isDark});
  final dynamic trip;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => TripDetailPage(tripId: trip.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${trip.departureCity} → ${trip.arrivalCity}',
                      style: AppTextStyles.titleMedium),
                  Text(trip.formattedPrice, style: AppTextStyles.priceSmall),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 14, color: AppColors.gray500),
                  const SizedBox(width: 4),
                  Text(trip.formattedDepartureTime,
                      style: AppTextStyles.bodyMedium),
                  const Spacer(),
                  Text('${trip.availableSeats} places libres',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Autocomplétion ville — dropdown en overlay flottant (ne décale plus le
// reste du formulaire, contrairement à un dropdown inline dans la Column)
// ─────────────────────────────────────────────────────────────────────────────

class _CityAutocomplete extends ConsumerStatefulWidget {
  const _CityAutocomplete({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  ConsumerState<_CityAutocomplete> createState() => _CityAutocompleteState();
}

class _CityAutocompleteState extends ConsumerState<_CityAutocomplete> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() async {
    final query = widget.controller.text;
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      _removeOverlay();
      return;
    }
    final results = await ref.read(tripServiceProvider).fetchCities(query);
    if (!mounted) return;
    setState(() => _suggestions = results);
    if (results.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: context.size?.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 46),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gray200),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final city = _suggestions[i];
                  return InkWell(
                    onTap: () {
                      widget.controller.text = city;
                      setState(() => _suggestions = []);
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.mobiliBlue),
                          const SizedBox(width: 8),
                          Text(city,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.mobiliBlueDeep)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon, size: 18),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    widget.controller.clear();
                    setState(() => _suggestions = []);
                    _removeOverlay();
                  },
                )
              : null,
        ),
      ),
    );
  }
}
