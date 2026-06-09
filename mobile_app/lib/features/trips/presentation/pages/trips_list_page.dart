import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/mobili_app_bar.dart';
import '../../../../shared/widgets/mobili_error_widget.dart';
import '../../../../shared/widgets/mobili_loader.dart';
import '../../providers/trip_provider.dart';
import '../widgets/trip_card.dart';

class TripsListPage extends ConsumerStatefulWidget {
  const TripsListPage({super.key});

  @override
  ConsumerState<TripsListPage> createState() => _TripsListPageState();
}

class _TripsListPageState extends ConsumerState<TripsListPage> {
  final _departureCtrl = TextEditingController();
  final _arrivalCtrl = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedType;
  bool _paramsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final dep = uri.queryParameters['departure'];
    final arr = uri.queryParameters['arrival'];
    if (dep != null && dep.isNotEmpty) {
      _departureCtrl.text = dep;
      _paramsInitialized = true;
    }
    if (arr != null && arr.isNotEmpty) {
      _arrivalCtrl.text = arr;
      _paramsInitialized = true;
    }
    if (_paramsInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateParams());
      _paramsInitialized = false;
    }
  }

  @override
  void dispose() {
    _departureCtrl.dispose();
    _arrivalCtrl.dispose();
    super.dispose();
  }

  void _updateParams() {
    final dep = _departureCtrl.text.trim();
    final arr = _arrivalCtrl.text.trim();
    final date = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;
    ref.read(tripSearchParamsProvider.notifier).state = TripSearchParams(
      departure: dep.isEmpty ? null : dep,
      arrival: arr.isEmpty ? null : arr,
      date: date,
      transportType: _selectedType,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _updateParams();
    }
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
    _updateParams();
  }

  void _selectType(String? value) {
    setState(() => _selectedType = value);
    _updateParams();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: MobiliAppBar(
        title: 'Mobili',
       actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.white),
            onPressed: () => context.go('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterSection(
            departureCtrl: _departureCtrl,
            arrivalCtrl: _arrivalCtrl,
            selectedDate: _selectedDate,
            selectedType: _selectedType,
            onFieldChanged: (_) => _updateParams(),
            onDateTap: _pickDate,
            onDateClear: _clearDate,
            onTypeSelected: _selectType,
          ),
          Container(height: 1, color: AppColors.gray200),
          Expanded(
            child: tripsAsync.when(
              loading: () => const _SkeletonList(),
              error: (error, _) => MobiliErrorWidget(
                error: MobiliErrorData.generic(error.toString()),
                onRetry: () => ref.invalidate(tripsProvider),
              ),
              data: (trips) {
                if (trips.isEmpty) {
                  return const EmptyStateWidget(type: MobiliEmptyType.trips);
                }
                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async => ref.invalidate(tripsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TripCard(
                          trip: trip,
                          onTap: () => context.go('/trips/${trip.id}'),
                        ),
                      );
                    },
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

// ─────────────────────────────────────────────────────────────────────────────
// Section filtres
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.departureCtrl,
    required this.arrivalCtrl,
    required this.selectedDate,
    required this.selectedType,
    required this.onFieldChanged,
    required this.onDateTap,
    required this.onDateClear,
    required this.onTypeSelected,
  });

  final TextEditingController departureCtrl;
  final TextEditingController arrivalCtrl;
  final DateTime? selectedDate;
  final String? selectedType;
  final ValueChanged<String> onFieldChanged;
  final VoidCallback onDateTap;
  final VoidCallback onDateClear;
  final ValueChanged<String?> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mobiliBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SearchInput(
                        controller: departureCtrl,
                        hint: 'Départ',
                        icon: Icons.trip_origin_rounded,
                        onChanged: onFieldChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SearchInput(
                        controller: arrivalCtrl,
                        hint: 'Arrivée',
                        icon: Icons.location_on_rounded,
                        onChanged: onFieldChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        selectedDate: selectedDate,
                        onTap: onDateTap,
                        onClear: onDateClear,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TransportDropdown(
                        selectedType: selectedType,
                        onTypeSelected: onTypeSelected,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x25000000), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Champ texte recherche
// ─────────────────────────────────────────────────────────────────────────────

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.mobiliBlueDeep,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.gray400,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, size: 18, color: AppColors.gray400),
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          borderSide: const BorderSide(color: AppColors.mobiliBlue, width: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur de date
// ─────────────────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({
    required this.selectedDate,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? selectedDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;
    final dateText =
        hasDate ? DateFormat('dd/MM/yyyy').format(selectedDate!) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 18,
                color: hasDate ? AppColors.mobiliBlue : AppColors.gray400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateText ?? 'Date',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: hasDate ? AppColors.mobiliBlueDeep : AppColors.gray400,
                  fontSize: 13,
                ),
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.gray400),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown type de transport
// ─────────────────────────────────────────────────────────────────────────────

class _TransportDropdown extends StatelessWidget {
  const _TransportDropdown({
    required this.selectedType,
    required this.onTypeSelected,
  });

  final String? selectedType;
  final ValueChanged<String?> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedType,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.gray400, size: 18),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.mobiliBlueDeep,
            fontSize: 13,
          ),
          dropdownColor: AppColors.white,
          items: const [
            DropdownMenuItem(value: null, child: Text('Tous')),
            DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
            DropdownMenuItem(value: 'COVOITURAGE', child: Text('Covoiturage')),
          ],
          onChanged: onTypeSelected,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton chargement
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 3,
      itemBuilder: (context, _) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: MobiliSkeletonBox(
          width: double.infinity,
          height: 120,
          borderRadius: 20,
        ),
      ),
    );
  }
}
