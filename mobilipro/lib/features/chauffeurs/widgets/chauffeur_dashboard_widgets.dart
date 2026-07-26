import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobilipro/features/chauffeurs/presentation/models/chauffeur_dashboard_models.dart';
import 'package:mobilipro/features/partner/presentation/pages/dashboard_partner_page.dart';

import '../../../../core/theme/app_colors.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.mobiliBlue),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.mobiliBlueDeep,
        ),
      ),
    ],
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  (String, Color, Color) _config(String status) {
    switch (status.toUpperCase()) {
      case 'EN_COURS':
        return (
          'En cours',
          AppColors.stationGreen.withValues(alpha: 0.15),
          AppColors.stationGreen,
        );
      case 'PLANIFIE':
      case 'PROGRAMMÉ':
      case 'PROGRAMME':
      case 'ASSIGNED':
        return (
          'Planifié',
          AppColors.mobiliBlue.withValues(alpha: 0.12),
          AppColors.mobiliBlue,
        );
      case 'TERMINÉ':
      case 'TERMINE':
      case 'COMPLETED':
        return ('Terminé', AppColors.gray100, AppColors.gray500);
      case 'ANNULÉ':
      case 'ANNULE':
      case 'CANCELLED':
        return ('Annulé', AppColors.dangerSoft, AppColors.danger);
      default:
        return (status, AppColors.gray100, AppColors.gray500);
    }
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.gray500),
          ),
        ],
      ),
    ),
  );
}

class RecentBookingCard extends StatelessWidget {
  const RecentBookingCard({super.key, required this.booking});
  final PartnerRecentBooking booking;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gray200),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.mobiliBlueFog,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              booking.displayInitial,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.mobiliBlue,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.mobiliBlueDeep,
                  fontSize: 13,
                ),
              ),
              Text(
                booking.tripRoute,
                style: const TextStyle(fontSize: 11, color: AppColors.gray400),
              ),
            ],
          ),
        ),
        Text(
          booking.formattedAmount,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.mobiliBlueDeep,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.white.withValues(alpha: 0.15)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mobiliYellow),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class NextTripCard extends StatelessWidget {
  const NextTripCard({super.key, required this.trip, required this.onDetail});
  final ChauffeurTripItem trip;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.departureCity,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.mobiliYellow.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.mobiliYellow,
                  size: 18,
                ),
              ),
              Expanded(
                child: Text(
                  trip.arrivalCity,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InfoChip(
                  icon: Icons.schedule_rounded,
                  label: 'Départ',
                  value: trip.formattedDate,
                ),
              ),
              const SizedBox(width: 10),
              if (trip.vehiculePlateNumber != null)
                Expanded(
                  child: InfoChip(
                    icon: Icons.directions_bus_rounded,
                    label: 'Véhicule',
                    value: trip.vehiculePlateNumber!,
                  ),
                ),
            ],
          ),
          if (trip.boardingPoint != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.mobiliYellow,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  trip.boardingPoint!,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              StatusBadge(status: trip.status),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onDetail,
                icon: const Icon(Icons.visibility_rounded, size: 15),
                label: const Text('Détails', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  side: BorderSide(
                    color: AppColors.white.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (trip.isInProgress || trip.isUpcoming)
                ElevatedButton.icon(
                  onPressed: () =>
                      context.go('/chauffeur/scanner?tripId=${trip.id}'),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text('Scanner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliYellow,
                    foregroundColor: AppColors.mobiliBlueDeep,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onDetail,
    this.isHistory = false,
  });
  final ChauffeurTripItem trip;
  final VoidCallback onDetail;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isHistory
                  ? AppColors.gray100
                  : AppColors.mobiliBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_bus_rounded,
              color: isHistory ? AppColors.gray400 : AppColors.mobiliBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.route,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mobiliBlueDeep,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  trip.formattedDate,
                  style: const TextStyle(
                    color: AppColors.gray400,
                    fontSize: 12,
                  ),
                ),
                if (trip.vehiculePlateNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    trip.vehiculePlateNumber!,
                    style: const TextStyle(
                      color: AppColors.gray400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: trip.status),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onDetail,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mobiliBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.mobiliBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 13,
                        color: AppColors.mobiliBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Voir',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mobiliBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
