import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/features/partner/providers/partner_shared_providers.dart';

import '../../../../core/theme/app_colors.dart';

class PartnerStationFilter extends ConsumerWidget {
  const PartnerStationFilter({
    super.key,
    required this.selectedStationId,
    required this.onChanged,
  });
  final int? selectedStationId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(partnerStationsProvider);
    return stationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (stations) {
        if (stations.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DropdownButtonFormField<int?>(
            initialValue: selectedStationId,
            decoration: InputDecoration(
              labelText: 'Gare',
              labelStyle: const TextStyle(fontSize: 11),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
            ),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mobiliBlueDeep,
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Toutes les gares'),
              ),
              ...stations.map(
                (s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
              ),
            ],
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}
