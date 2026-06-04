import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_loader.dart';
import '../../providers/trip_provider.dart';
import '../../domain/models/trip.dart';
import '../../../bookings/presentation/pages/booking_page.dart';

class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({super.key, required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final stopsAsync = ref.watch(tripStopsProvider(tripId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.gray50,
      body: tripAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Détail du trajet')),
          body: Center(child: Text('Erreur: $e')),
        ),
        data: (trip) => _TripDetailContent(
          trip: trip,
          stopsAsync: stopsAsync,
          isDark: isDark,
          tripId: tripId,
        ),
      ),
    );
  }
}

class _TripDetailContent extends StatelessWidget {
  const _TripDetailContent({
    required this.trip,
    required this.stopsAsync,
    required this.isDark,
    required this.tripId,
  });

  final Trip trip;
  final AsyncValue stopsAsync;
  final bool isDark;
  final int tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.gray50,

      // ── AppBar avec image véhicule en fond ──────────────────────────
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.mobiliBlue,
            iconTheme: const IconThemeData(color: AppColors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: trip.vehicleImageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'http://10.0.2.2:8080/v1/uploads/${trip.vehicleImageUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.mobiliBlue,
                            child: const Icon(Icons.directions_bus_rounded,
                                color: AppColors.white, size: 64),
                          ),
                        ),
                        // Dégradé pour lisibilité du titre
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0xCC05164D),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: AppColors.mobiliBlue),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte infos principales ──────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                    boxShadow: AppColors.shadowSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              trip.departureCity,
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.mobiliBlueDeep,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.arrow_forward_rounded,
                                color: AppColors.mobiliBlue, size: 20),
                          ),
                          Flexible(
                            child: Text(
                              trip.arrivalCity,
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.mobiliBlueDeep,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Date départ
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 16, color: AppColors.mobiliBlue),
                          const SizedBox(width: 8),
                          Text(
                            'Départ : ${trip.formattedDepartureFull}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.gray700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Point embarquement
                      if (trip.boardingPoint != null &&
                          trip.boardingPoint!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.mobiliYellow.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Text('📍', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Embarquement : ${trip.boardingPoint}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.mobiliBlueDeep,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const Divider(color: AppColors.gray100),
                      const SizedBox(height: 8),

                      // Prix + places + type véhicule
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.formattedPrice,
                                style: AppTextStyles.price.copyWith(
                                  fontSize: 26,
                                  color: AppColors.mobiliBlueDeep,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Tarif unique',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.gray400,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${trip.availableSeats} place${trip.availableSeats > 1 ? 's' : ''} restante${trip.availableSeats > 1 ? 's' : ''}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: trip.availableSeats <= 3
                                      ? AppColors.warning
                                      : AppColors.stationGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (trip.vehicleTypeLabel.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.stationGreenSoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    trip.vehicleTypeLabel,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.stationGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Escales ──────────────────────────────────────────
                if (trip.moreInfo != null && trip.moreInfo!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Villes desservies',
                            style: AppTextStyles.titleLarge),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: trip.moreInfo!
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .map((stop) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: AppColors.gray200),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(stop,
                                        style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.gray600)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                // ── Arrêts et horaires ────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arrêts et Horaires',
                          style: AppTextStyles.titleLarge),
                      const SizedBox(height: 10),
                      stopsAsync.when(
                        loading: () => const MobiliInlineLoader(),
                        error: (_, __) =>
                            const Text('Erreur chargement arrêts'),
                        data: (stops) {
                          if (stops.isEmpty) {
                            return Text('Aucun arrêt enregistré',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.gray400));
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: stops.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: AppColors.gray100),
                            itemBuilder: (_, i) {
                              final stop = stops[i];
                              final isFirst = i == 0;
                              final isLast = i == stops.length - 1;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    // Icône arrêt
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isFirst || isLast
                                            ? AppColors.mobiliBlue
                                            : AppColors.mobiliBlueFog,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isFirst
                                            ? Icons.trip_origin_rounded
                                            : isLast
                                                ? Icons.location_on_rounded
                                                : Icons
                                                    .radio_button_checked_rounded,
                                        color: isFirst || isLast
                                            ? AppColors.white
                                            : AppColors.mobiliBlue,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        stop.cityName,
                                        style:
                                            AppTextStyles.titleMedium.copyWith(
                                          fontWeight: isFirst || isLast
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isFirst || isLast
                                              ? AppColors.mobiliBlueDeep
                                              : AppColors.gray700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      stop.formattedTime,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.mobiliBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── Bouton Réserver fixe en bas ──────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.mobiliBlueDeep.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: MobiliButton(
          label: trip.availableSeats > 0 ? 'Réserver ce trajet' : 'Complet',
          enabled: trip.availableSeats > 0,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => BookingPage(trip: trip)),
          ),
        ),
      ),
    );
  }
}
