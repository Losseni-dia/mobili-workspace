import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../trips/domain/models/trip.dart';
import '../../providers/covoiturage_provider.dart';

/// Dashboard "Espace covoiturage" — synthèse partenaire (créer/modifier ses
/// trajets) + gare (réservations) + chauffeur (conduite), pour un même
/// conducteur particulier. Même logique de regroupement que le dashboard
/// chauffeur MobiliPro : aujourd'hui/demain en avant, historique à part.
class CovoiturageDashboardPage extends ConsumerWidget {
  const CovoiturageDashboardPage({super.key});

  void _openDetail(BuildContext context, Trip trip) {
    context.push('/covoiturage/trips/${trip.id}/detail', extra: trip);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(myCovoiturageTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text('Espace covoiturage',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Mon profil conducteur',
            onPressed: () => context.push('/covoiturage/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/covoiturage/trips/new'),
        backgroundColor: AppColors.mobiliYellow,
        foregroundColor: AppColors.mobiliBlueDeep,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Publier un trajet', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async => ref.invalidate(myCovoiturageTripsProvider),
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                  const SizedBox(height: 12),
                  Text('$e', style: const TextStyle(color: AppColors.gray500)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(myCovoiturageTripsProvider),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
          data: (trips) {
            if (trips.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.mobiliBlueFog,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.directions_car_filled_rounded,
                            color: AppColors.mobiliBlue, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text('Aucun trajet publié',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.mobiliBlueDeep,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 6),
                      Text(
                        'Publiez votre premier trajet covoiturage avec le bouton ci-dessous.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray500),
                      ),
                    ],
                  ),
                ),
              );
            }

            final inProgress = trips.where((t) => t.isInProgress).toList();
            final relevant = trips
                .where((t) => t.isInProgress || t.isToday || t.isTomorrow)
                .toList()
              ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
            final history =
                trips.where((t) => t.isCompleted || t.isCancelled).toList()
                  ..sort((a, b) => b.departureTime.compareTo(a.departureTime));
            final next = inProgress.isNotEmpty
                ? inProgress.first
                : (relevant.isNotEmpty ? relevant.first : null);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (next != null) ...[
                  const _SectionTitle(icon: Icons.navigate_next_rounded, label: 'Prochain trajet'),
                  const SizedBox(height: 10),
                  _NextTripCard(trip: next, onTap: () => _openDetail(context, next)),
                  const SizedBox(height: 20),
                ],

                Row(
                  children: [
                    const _SectionTitle(icon: Icons.today_rounded, label: 'Aujourd\'hui & demain'),
                    const Spacer(),
                    if (relevant.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.mobiliBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${relevant.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (relevant.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                        SizedBox(width: 10),
                        Text('Aucun trajet aujourd\'hui ou demain',
                            style: TextStyle(color: AppColors.gray500, fontSize: 13)),
                      ],
                    ),
                  )
                else
                  ...relevant.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TripCard(trip: t, onTap: () => _openDetail(context, t)),
                      )),

                const SizedBox(height: 20),
                _HistoryLink(
                  count: history.length,
                  onTap: () => context.push('/covoiturage/history', extra: history),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Historique
// ─────────────────────────────────────────────────────────────────────────────

class CovoiturageHistoryPage extends StatelessWidget {
  const CovoiturageHistoryPage({super.key, required this.trips});
  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text('Historique', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: trips.isEmpty
          ? const Center(
              child: Text('Aucun trajet passé', style: TextStyle(color: AppColors.gray400)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TripCard(
                  trip: trips[i],
                  isHistory: true,
                  onTap: () =>
                      context.push('/covoiturage/trips/${trips[i].id}/detail', extra: trips[i]),
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cartes
// ─────────────────────────────────────────────────────────────────────────────

class _NextTripCard extends StatelessWidget {
  const _NextTripCard({required this.trip, required this.onTap});
  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bookedSeats = trip.totalSeats - trip.availableSeats;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(trip.departureCity,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.mobiliYellow),
                Expanded(
                  child: Text(trip.arrivalCity,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Text(trip.formattedDepartureFull,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatusPill(status: trip.status ?? 'PROGRAMMÉ'),
                const Spacer(),
                Text(
                  bookedSeats > 0 ? '$bookedSeats réservé(s)' : 'Aucune réservation',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap, this.isHistory = false});
  final Trip trip;
  final VoidCallback onTap;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final bookedSeats = trip.totalSeats - trip.availableSeats;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isHistory ? AppColors.gray100 : AppColors.mobiliBlueFog,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.directions_car_filled_rounded,
                  color: isHistory ? AppColors.gray400 : AppColors.mobiliBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${trip.departureCity} → ${trip.arrivalCity}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.mobiliBlueDeep,
                        fontWeight: FontWeight.w700,
                      )),
                  Text(trip.formattedDepartureFull,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400)),
                  if (bookedSeats > 0)
                    Text('$bookedSeats réservé(s) · ${trip.formattedPrice}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400, fontSize: 11)),
                ],
              ),
            ),
            _StatusPill(status: trip.status ?? 'PROGRAMMÉ'),
          ],
        ),
      ),
    );
  }
}

class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.mobiliBlue, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Historique des trajets',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mobiliBlueDeep, fontSize: 14)),
              ),
              if (count > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(20)),
                  child: Text('$count',
                      style: const TextStyle(color: AppColors.gray500, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
            ],
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status.toUpperCase()) {
      'EN_COURS' => ('En cours', AppColors.success),
      'PROGRAMMÉ' || 'PROGRAMME' => ('Programmé', AppColors.mobiliBlue),
      'TERMINÉ' || 'TERMINE' => ('Terminé', AppColors.gray500),
      'ANNULÉ' || 'ANNULE' => ('Annulé', AppColors.danger),
      _ => (status, AppColors.gray500),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mobiliBlue),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.mobiliBlueDeep)),
        ],
      );
}
