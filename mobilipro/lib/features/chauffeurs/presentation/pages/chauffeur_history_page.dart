import 'package:flutter/material.dart';
import 'package:mobilipro/features/chauffeurs/widgets/chauffeur_dashboard_widgets.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/chauffeur_dashboard_models.dart';
import 'trip_detail_chauffeur_page.dart';

class ChauffeurHistoryPage extends StatelessWidget {
  const ChauffeurHistoryPage({super.key, required this.history});
  final List<ChauffeurTripItem> history;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Historique des trajets',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: AppColors.gray300,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Aucun trajet passé',
                      style: TextStyle(color: AppColors.gray400, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TripCard(
                  trip: history[i],
                  isHistory: true,
                  onDetail: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripDetailChauffeurPage(trip: history[i]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
