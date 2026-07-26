import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../stations/presentation/pages/gare_detail_page.dart';
import '../../providers/partner_shared_providers.dart';

class PartnerStationsListPage extends ConsumerWidget {
  const PartnerStationsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(partnerStationsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Mes gares',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: stationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erreur : $e',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (stations) => stations.isEmpty
            ? const Center(
                child: Text(
                  'Aucune gare',
                  style: TextStyle(color: AppColors.gray400),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: stations
                    .map(
                      (s) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: s.active
                                ? AppColors.stationGreen.withValues(alpha: 0.3)
                                : AppColors.gray200,
                          ),
                          boxShadow: AppColors.shadowSm,
                        ),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GareDetailPage(
                                stationId: s.id,
                                stationName: s.name,
                                city: s.city,
                                active: s.active,
                                responsibleName: s.responsibleName,
                                chauffeurs: s.chauffeurs,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: s.active
                                      ? AppColors.stationGreen.withValues(
                                          alpha: 0.1,
                                        )
                                      : AppColors.gray100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.store_rounded,
                                  size: 24,
                                  color: s.active
                                      ? AppColors.stationGreen
                                      : AppColors.gray400,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.mobiliBlueDeep,
                                      ),
                                    ),
                                    Text(
                                      s.city,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person_rounded,
                                          size: 12,
                                          color: AppColors.gray400,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          s.responsibleName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.gray400,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.directions_car_rounded,
                                          size: 12,
                                          color: AppColors.gray400,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${s.chauffeurs.length} chauffeur(s)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.gray400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                    )
                    .toList(),
              ),
      ),
    );
  }
}
