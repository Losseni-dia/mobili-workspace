import 'package:flutter/material.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/covoiturage_provider.dart';

class CovoiturageBookingsListPage extends StatelessWidget {
  const CovoiturageBookingsListPage({super.key, required this.bookings});
  final List<PartnerRecentBooking> bookings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: const MobiliAppBar(
          title: 'Mes réservations', showBackButton: true, showPattern: true),
      body: bookings.isEmpty
          ? const Center(
              child: Text('Aucune réservation',
                  style: TextStyle(color: AppColors.gray400)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, i) {
                final b = bookings[i];
                final (label, bg, fg) = _statusConfig(b.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.displayName,
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.mobiliBlueDeep,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(b.tripRoute,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.gray400)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(b.formattedAmount,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.mobiliBlueDeep,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: fg,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  (String, Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return ('Confirmée', const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'OFFLINE_SALE':
        return (
          'Achat physique',
          AppColors.mobiliBlueFog,
          AppColors.mobiliBlue
        );
      case 'PENDING':
      case 'PENDING_DRIVER_APPROVAL':
        return ('En attente', AppColors.warningSoft, AppColors.warning);
      case 'AWAITING_PAYMENT':
        return (
          'À payer',
          AppColors.mobiliYellow.withValues(alpha: 0.2),
          AppColors.mobiliBlueDeep
        );
      case 'CANCELLED':
        return ('Annulée', AppColors.dangerSoft, AppColors.danger);
      case 'REJECTED_BY_DRIVER':
        return ('Refusée', AppColors.dangerSoft, AppColors.danger);
      case 'EXPIRED':
        return ('Expirée', AppColors.dangerSoft, AppColors.danger);
      case 'COMPLETED':
        return ('Terminée', AppColors.gray100, AppColors.gray500);
      default:
        return (status, AppColors.gray100, AppColors.gray500);
    }
  }
}
