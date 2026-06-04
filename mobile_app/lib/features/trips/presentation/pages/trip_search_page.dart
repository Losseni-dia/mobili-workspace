import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _departureCtrl = TextEditingController();
  final _arrivalCtrl = TextEditingController();
  DateTime? _selectedDate;
  String? _transportType;

  @override
  void dispose() {
    _departureCtrl.dispose();
    _arrivalCtrl.dispose();
    super.dispose();
  }

  void _search() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    ref.read(tripSearchParamsProvider.notifier).state = TripSearchParams(
      departure: _departureCtrl.text.trim(),
      arrival: _arrivalCtrl.text.trim(),
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
    ref.read(tripSearchParamsProvider.notifier).state = const TripSearchParams();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripsAsync = ref.watch(tripsProvider);
    final searchParams = ref.watch(tripSearchParamsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.gray50,
      appBar: AppBar(
        title: const Text('Trouver un trajet'),
        actions: [
          if (!searchParams.isEmpty)
            TextButton(
              onPressed: _clearSearch,
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _FormInput(
                          controller: _departureCtrl,
                          label: 'Départ',
                          hint: 'Abidjan',
                          icon: Icons.trip_origin,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormInput(
                          controller: _arrivalCtrl,
                          label: 'Arrivée',
                          hint: 'Bouaké',
                          icon: Icons.place_outlined,
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
                            if (picked != null) setState(() => _selectedDate = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                              fillColor: isDark ? AppColors.darkSurfaceRaised : AppColors.gray50,
                            ),
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
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
                            prefixIcon: const Icon(Icons.directions_bus_outlined, size: 18),
                            fillColor: isDark ? AppColors.darkSurfaceRaised : AppColors.gray50,
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Tous')),
                            DropdownMenuItem(value: 'BUS', child: Text('Bus')),
                            DropdownMenuItem(value: 'MINIBUS', child: Text('Minibus')),
                          ],
                          onChanged: (v) => setState(() => _transportType = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MobiliButton(
                    label: 'Rechercher un trajet',
                    icon: Icons.search,
                    onPressed: _search,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          // Section Résultats branchée sur nos composants Skeletons Low-End
          Expanded(
            child: tripsAsync.when(
              loading: () => const MobiliSkeletonList(count: 4), // Custom skeleton loader (Agent 3)
              error: (err, _) => MobiliErrorWidget(
                error: MobiliErrorData(errorCode: 'NET', message: err.toString()),
                onRetry: () => ref.invalidate(tripsProvider),
              ),
              data: (trips) {
                if (trips.isEmpty) {
                  return const EmptyStateWidget(type: MobiliEmptyType.trips);
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(tripsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _TripCard(trip: trips[i], isDark: isDark),
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

class _FormInput extends StatelessWidget {
  const _FormInput({required this.controller, required this.label, required this.hint, required this.icon});
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
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
          MaterialPageRoute<void>(builder: (_) => TripDetailPage(tripId: trip.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${trip.departureCity} → ${trip.arrivalCity}', style: AppTextStyles.titleMedium),
                  Text(trip.formattedPrice, style: AppTextStyles.priceSmall),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.gray500),
                  const SizedBox(width: 4),
                  Text(trip.formattedDepartureTime, style: AppTextStyles.bodyMedium),
                  const Spacer(),
                  Text('${trip.availableSeats} places libres', style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}