import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';
import 'package:mobili/shared/widgets/private_network_image.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_loader.dart';
import '../../providers/trip_provider.dart';
import '../../domain/models/trip.dart';
import '../../../bookings/presentation/pages/booking_page.dart';
import '../widgets/trip_live_map.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider note moyenne
// ─────────────────────────────────────────────────────────────────────────────

final _tripRatingProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, tripId) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<Map<String, dynamic>>(
    '/trips/$tripId/ratings/average',
  );
  return response.data ?? {'average': 0.0, 'count': 0};
});

class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({super.key, required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final stopsAsync = ref.watch(tripStopsProvider(tripId));
    final ratingAsync = ref.watch(_tripRatingProvider(tripId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.mobiliYellowPale,
      body: tripAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: const MobiliAppBar(
            title: 'Détail du trajet',
            showBackButton: true,
          ),
          body: Center(child: Text('Erreur: $e')),
        ),
        data: (trip) => _TripDetailContent(
          trip: trip,
          stopsAsync: stopsAsync,
          ratingAsync: ratingAsync,
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
    required this.ratingAsync,
    required this.isDark,
    required this.tripId,
  });

  final Trip trip;
  final AsyncValue stopsAsync;
  final AsyncValue<Map<String, dynamic>> ratingAsync;
  final bool isDark;
  final int tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.mobiliYellowPale,
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
                          '${ApiConstants.baseUrl}/uploads/${trip.vehicleImageUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.mobiliBlue,
                            child: const Icon(Icons.directions_bus_rounded,
                                color: AppColors.white, size: 64),
                          ),
                        ),
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
                // ── Carte infos principales ──────────────
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

                      // Note moyenne
                      ratingAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (rating) {
                          final avg = (rating['average'] as num).toDouble();
                          final count = (rating['count'] as num).toInt();
                          if (count == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RatingBar(average: avg, count: count),
                          );
                        },
                      ),

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

                // ── Suivi temps réel (trajet EN_COURS uniquement) ─
                if (trip.isInProgress) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _EtaBadge(trip: trip),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: TripLiveMap(tripId: trip.id),
                  ),
                ],

                // ── Escales ──────────────────────────────
               // ── Conducteur (covoiturage uniquement) ───
                if (trip.isCovoiturage &&
                    (trip.covoiturageOrganizerFirstname != null ||
                        trip.covoiturageOrganizerDriverPhotoUrl != null))
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.mobiliBlue, width: 2),
                            color: AppColors.mobiliBlueFog,
                          ),
                          child: ClipOval(
                            child:
                                trip.covoiturageOrganizerDriverPhotoUrl != null
                                    ? PrivateNetworkImage(
                                        relativePath: trip
                                            .covoiturageOrganizerDriverPhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: const Icon(
                                            Icons.person_rounded,
                                            color: AppColors.mobiliBlue,
                                            size: 28),
                                      )
                                    : const Icon(Icons.person_rounded,
                                        color: AppColors.mobiliBlue, size: 28),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Votre conducteur',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.gray400, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                '${trip.covoiturageOrganizerFirstname ?? ''} ${trip.covoiturageOrganizerLastname ?? ''}'
                                    .trim(),
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.mobiliBlueDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Arrêts et horaires ────────────────────
                // (La section "Villes desservies" — simple liste de badges
                // avec les mêmes villes — a été retirée : redondante avec
                // celle-ci, qui affiche les mêmes arrêts avec les horaires
                // en plus.)
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
                          return _StopsTimeline(stops: stops);
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
        // Redevenu un simple MobiliButton (comme à l'origine) : l'ajout du
        // prix via Row+Column+Expanded ici est suspecté d'être la cause du
        // rendu cassé constaté en test réel (contenu de la page invisible,
        // bouton flottant) — retiré le temps de confirmer par isolation.
        child: MobiliButton.secondary(
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

// ─────────────────────────────────────────────────────────────────────────────
// Badge ETA — "En route vers X — dans Y min", alimenté par tripEtaProvider
// (recalcul toutes les 5 min, voir trip_provider.dart). Affiché uniquement
// pendant trip.isInProgress (voir _TripDetailContent ci-dessus).
// ─────────────────────────────────────────────────────────────────────────────

class _EtaBadge extends ConsumerWidget {
  const _EtaBadge({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etaState = ref.watch(tripEtaProvider(trip.id));
    final eta = etaState.eta;
    final destination = eta?.destinationCity ?? trip.nextStopCity;

    final String label;
    if (eta == null) {
      // Position pas encore reçue (TripLiveMap vient de se monter) ou 1er
      // calcul en cours — jamais d'estimation inventée entre-temps.
      label = destination != null ? 'En route vers $destination' : 'En route';
    } else if (!eta.available) {
      // Prochain arrêt sans coordonnées renseignées (voir backend
      // TripEtaService) — jamais une estimation approximative.
      label = 'En route vers ${destination ?? ''} — Temps restant indisponible';
    } else {
      label = 'En route vers ${destination ?? ''} — dans ${eta.durationLabel}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mobiliBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_bus_filled_rounded,
              size: 18, color: AppColors.mobiliBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.mobiliBlueDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline arrêts — ligne horizontale connectant les points, défilable.
// Anciennement une Column verticale (une ligne par arrêt) : avec beaucoup de
// tronçons, la page détail s'allongeait indéfiniment. Passée en Row
// défilable horizontalement (retour utilisateur) — hauteur fixe pour cette
// section quel que soit le nombre d'arrêts.
// ─────────────────────────────────────────────────────────────────────────────

class _StopsTimeline extends StatelessWidget {
  const _StopsTimeline({required this.stops});
  final List<dynamic> stops;

  /// Largeur réservée à chaque arrêt (nom de ville + heure en dessous du
  /// point) — assez pour un nom de ville moyen sans wrap intempestif.
  static const double _stopWidth = 92;
  static const double _dotAreaHeight = 24;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Stack(
        children: [
          // Ligne continue en fond, à hauteur du centre des points — même
          // principe que l'ancienne version verticale, juste retournée.
          Positioned(
            top: _dotAreaHeight / 2 - 1,
            left: _stopWidth / 2,
            right: _stopWidth / 2,
            child: Container(
              height: 2,
              color: AppColors.mobiliBlue.withValues(alpha: 0.25),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(stops.length, (i) {
              final stop = stops[i];
              final isFirst = i == 0;
              final isLast = i == stops.length - 1;
              return SizedBox(
                width: _stopWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: _dotAreaHeight,
                      child: Center(
                        child: Container(
                          width: isFirst || isLast ? 16 : 10,
                          height: isFirst || isLast ? 16 : 10,
                          decoration: BoxDecoration(
                            color: isFirst || isLast
                                ? AppColors.mobiliBlue
                                : AppColors.white,
                            shape: BoxShape.circle,
                            border: isFirst || isLast
                                ? null
                                : Border.all(
                                    color: AppColors.mobiliBlue, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stop.cityName as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 13,
                        fontWeight:
                            isFirst || isLast ? FontWeight.w700 : FontWeight.w500,
                        color: isFirst || isLast
                            ? AppColors.mobiliBlueDeep
                            : AppColors.gray700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.formattedTime as String,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 12,
                        color: AppColors.mobiliBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget barre de note
// ─────────────────────────────────────────────────────────────────────────────

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.average, required this.count});
  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mobiliYellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.mobiliYellow.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Étoiles
          ...List.generate(5, (i) {
            final star = i + 1;
            if (star <= average.floor()) {
              return const Icon(Icons.star_rounded,
                  color: AppColors.mobiliYellow, size: 18);
            } else if (star - 1 < average && average < star) {
              return const Icon(Icons.star_half_rounded,
                  color: AppColors.mobiliYellow, size: 18);
            } else {
              return Icon(Icons.star_outline_rounded,
                  color: AppColors.mobiliYellow.withValues(alpha: 0.4),
                  size: 18);
            }
          }),
          const SizedBox(width: 8),
          Text(
            average.toStringAsFixed(1),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.mobiliBlueDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count avis)',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.gray500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
