import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/trip.dart';

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
  });

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFull = trip.availableSeats == 0;

    return GestureDetector(
      onTap: isFull ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: isFull ? 0.6 : 1.0,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VehicleImage(url: trip.vehicleImageUrl),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 4, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Route
                        _RouteRow(
                          departure: trip.departureCity,
                          arrival: trip.arrivalCity,
                        ),
                        const SizedBox(height: 4),

                        // Date + heure
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 12, color: AppColors.gray400),
                            const SizedBox(width: 4),
                            Text(
                              trip.formattedDepartureFull,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.gray600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Point d'embarquement — pleine largeur
                        if (trip.boardingPoint != null &&
                            trip.boardingPoint!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.mobiliYellow
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Text('📍',
                                    style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Emb. : ${trip.boardingPoint}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.mobiliBlueDeep,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Escales en chips
                        if (trip.moreInfo != null && trip.moreInfo!.isNotEmpty)
                          _EscalesChips(moreInfo: trip.moreInfo!),

                        const SizedBox(height: 6),

                        // Bas : type véhicule • partenaire (sans badge transport)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (trip.vehicleTypeLabel.isNotEmpty)
                              _VehicleTypeBadge(label: trip.vehicleTypeLabel),
                            if (trip.partnerName != null)
                              Text(
                                trip.partnerName!
                                    .replaceAll(RegExp(r'\s*\(.*?\)\s*'), '')
                                    .trim(),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.gray500,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _RightBlock(trip: trip, onTap: onTap, isFull: isFull),
              ],
            ),
          ), // ← ferme Row
        ), // ← ferme IntrinsicHeight
      ), // ← ferme Opacity
      // ← ferme Container
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image véhicule
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.url});
  final String? url;

  @override
 Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: SizedBox(
          width: 110,
          child: url != null
              ? Container(
                  color: AppColors.gray100,
                  child: Image.network(
                    'http://10.0.2.2:8080/v1/uploads/$url',
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  ),
                )
              : _placeholder(),
        ),
      ),
    );
  }
  
  Widget _placeholder() => Container(
        color: AppColors.mobiliBlueFog,
        child: const Center(
          child: Icon(
            Icons.directions_bus_rounded,
            color: AppColors.mobiliBlue,
            size: 36,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Route row
// ─────────────────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.departure, required this.arrival});
  final String departure;
  final String arrival;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            departure,
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.mobiliBlueDeep,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded,
              size: 14, color: AppColors.mobiliBlue),
        ),
        Flexible(
          child: Text(
            arrival,
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.mobiliBlueDeep,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Escales en chips
// ─────────────────────────────────────────────────────────────────────────────

class _EscalesChips extends StatelessWidget {
  const _EscalesChips({required this.moreInfo});
  final String moreInfo;

  @override
  Widget build(BuildContext context) {
    final stops = moreInfo
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSANT PAR :',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.gray400,
            fontSize: 9,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: stops
              .map((stop) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray200),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      stop,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.gray600,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge type véhicule uniquement
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleTypeBadge extends StatelessWidget {
  const _VehicleTypeBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.stationGreenSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.stationGreen,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bloc droit : prix + places + bouton
// ─────────────────────────────────────────────────────────────────────────────

class _RightBlock extends StatelessWidget {
  const _RightBlock({
    required this.trip,
    required this.onTap,
    required this.isFull,
  });
  final Trip trip;
  final VoidCallback onTap;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.fromLTRB(8, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Prix
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trip.priceXof.toStringAsFixed(0),
                style: AppTextStyles.price.copyWith(
                  color: AppColors.mobiliBlueDeep,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'FCFA',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.gray400,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Places restantes
          Text(
            isFull
                ? 'Complet'
                : '${trip.availableSeats} place${trip.availableSeats > 1 ? 's' : ''} restante${trip.availableSeats > 1 ? 's' : ''}',
            style: AppTextStyles.bodySmall.copyWith(
              color: isFull
                  ? AppColors.danger
                  : trip.availableSeats <= 3
                      ? AppColors.warning
                      : AppColors.stationGreen,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 10),

          // Bouton Réserver
          if (!isFull)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mobiliYellow,
                  foregroundColor: AppColors.mobiliBlueDeep,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(0, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Réserver',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.mobiliBlueDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COMPLET',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.danger,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
