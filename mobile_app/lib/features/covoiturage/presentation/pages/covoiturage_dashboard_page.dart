import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobili/features/covoiturage/presentation/pages/covoiturage_apply_page.dart';
import 'package:mobili/shared/widgets/private_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/models/profile_dto.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../trips/domain/models/trip.dart';
import '../../providers/covoiturage_provider.dart';

class CovoiturageDashboardPage extends ConsumerStatefulWidget {
  const CovoiturageDashboardPage({super.key});

  @override
  ConsumerState<CovoiturageDashboardPage> createState() =>
      _CovoiturageDashboardPageState();
}

class _CovoiturageDashboardPageState
    extends ConsumerState<CovoiturageDashboardPage> {
  @override
  void initState() {
    super.initState();
    // Les providers ne sont plus autoDispose (pour éviter le clignotement au
    // va-et-vient entre écrans) : on force donc un refresh actif à chaque
    // ouverture du dashboard, pour rattraper un éventuel échec initial (ex.
    // au démarrage à froid de l'app, avant que le token JWT soit prêt) qui
    // sinon resterait bloqué indéfiniment sans nouvelle tentative.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshProfile();
      ref.invalidate(myCovoiturageTripsProvider);
    });
  }

  void _openDetail(BuildContext context, Trip trip) {
    context.push('/covoiturage/trips/${trip.id}/detail', extra: trip);
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myCovoiturageTripsProvider);
    final profile = ref.watch(currentProfileProvider);
    return PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop) context.go('/profile');
  },
  child: Scaffold(
    backgroundColor: AppColors.gray50,
    appBar: AppBar(
         backgroundColor: AppColors.mobiliBlue,
          foregroundColor: AppColors.white,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          title: const Text('Dashboard covoiturage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scanner un billet',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CovoiturageScannerPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Mon profil conducteur',
            onPressed: () => context.push('/covoiturage/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/covoiturage/trips/new');
          ref.invalidate(myCovoiturageTripsProvider);
        },
        backgroundColor: AppColors.mobiliYellow,
        foregroundColor: AppColors.mobiliBlueDeep,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Publier un trajet',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async => ref.invalidate(myCovoiturageTripsProvider),
        child: tripsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 48),
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
            final inProgress = trips.where((t) => t.isInProgress).toList();
            final relevant = trips
                .where((t) => t.isInProgress || t.isToday || t.isTomorrow)
                .toList()
              ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
            final history = trips
                .where((t) => t.isCompleted || t.isCancelled)
                .toList()
              ..sort((a, b) => b.departureTime.compareTo(a.departureTime));
            final next = inProgress.isNotEmpty
                ? inProgress.first
                : (relevant.isNotEmpty ? relevant.first : null);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // ── Carte conducteur ──────────────────────────────────
                if (profile != null) ...[
                  _DriverCard(profile: profile),
                  const SizedBox(height: 20),
                ],

                // ── Prochain trajet ───────────────────────────────────
                if (next != null) ...[
                  const _SectionTitle(
                      icon: Icons.navigate_next_rounded,
                      label: 'Prochain trajet'),
                  const SizedBox(height: 10),
                  _NextTripCard(
                      trip: next, onTap: () => _openDetail(context, next)),
                  const SizedBox(height: 20),
                ],

                // ── Aujourd'hui & demain ──────────────────────────────
                Row(
                  children: [
                    const _SectionTitle(
                        icon: Icons.today_rounded,
                        label: 'Aujourd\'hui & demain'),
                    const Spacer(),
                    if (relevant.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.mobiliBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${relevant.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (trips.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.mobiliBlueFog,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                                Icons.directions_car_filled_rounded,
                                color: AppColors.mobiliBlue,
                                size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text('Aucun trajet publié',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.mobiliBlueDeep,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 6),
                          Text(
                            'Publiez votre premier trajet avec le bouton ci-dessous.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.gray500),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (relevant.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.success, size: 20),
                        SizedBox(width: 10),
                        Text('Aucun trajet aujourd\'hui ou demain',
                            style: TextStyle(
                                color: AppColors.gray500, fontSize: 13)),
                      ],
                    ),
                  )
                else
                  ...relevant.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TripCard(
                            trip: t, onTap: () => _openDetail(context, t)),
                      )),

               const SizedBox(height: 20),
                  if (trips.isNotEmpty) ...[
                    _AllTripsLink(
                      count: trips.length,
                      onTap: () => context.push(
                        '/covoiturage/all-trips',
                        extra: List<Trip>.from(trips)
                          ..sort((a, b) =>
                              a.departureTime.compareTo(b.departureTime)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _HistoryLink(
                      count: history.length,
                      onTap: () =>
                          context.push('/covoiturage/history', extra: history),
                    ),
                  ],
                ],
              );
          },
        ),
      ),
    ),
  );
 }
}


// ─────────────────────────────────────────────────────────────────────────────
// Carte conducteur
// ─────────────────────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.profile});
  final ProfileDto profile;

  @override
  Widget build(BuildContext context) {
    final kycStatus = profile.covoiturageKycStatus ?? 'NONE';
    final (kycLabel, kycColor) = switch (kycStatus) {
      'APPROVED' => ('Conducteur vérifié ✓', AppColors.success),
      'PENDING' => ('Validation en cours', AppColors.warning),
      'REJECTED' => ('Dossier refusé', AppColors.danger),
      'EXPIRED' => ('CNI expirée', AppColors.danger),
      _ => ('Non vérifié', AppColors.gray400),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar conducteur
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.mobiliYellow, width: 2),
                  color: AppColors.mobiliBlue,
                ),
                child: ClipOval(
                  child: profile.avatarUrl != null
                      ? Image.network(
                          'https://api.my-mobili.com/v1/uploads/${profile.avatarUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: AppColors.white,
                              size: 28),
                        )
                      : const Icon(Icons.person_rounded,
                          color: AppColors.white, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.firstname ?? ''} ${profile.lastname ?? ''}'
                          .trim(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kycColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: kycColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(kycLabel,
                          style: TextStyle(
                              color: kycColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Photo véhicule + infos
          if (profile.covoiturageVehiclePhotoUrl != null ||
              profile.covoiturageVehicleBrand != null) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                // Photo véhicule
               if (profile.covoiturageVehiclePhotoUrl != null)
                  Container(
                    width: 80,
                    height: 56,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PrivateNetworkImage(
                        relativePath: profile.covoiturageVehiclePhotoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: const Center(
                          child: Icon(Icons.directions_car_rounded,
                              color: Colors.white54, size: 28),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile.covoiturageVehicleBrand != null)
                        Text(profile.covoiturageVehicleBrand!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      if (profile.covoiturageVehiclePlate != null)
                        Text(profile.covoiturageVehiclePlate!,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12)),
                      if (profile.covoiturageVehicleColor != null)
                        Text(profile.covoiturageVehicleColor!,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12)),
                    ],
                  ),
                ),
                // Bouton modifier profil
                GestureDetector(
                  onTap: () => context.push('/covoiturage/profile'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text('Modifier',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Alerte CNI
          if (profile.covoiturageKycExpiringWithin30Days == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Votre CNI expire bientôt — pensez à mettre à jour votre dossier.',
                      style: TextStyle(
                          color: AppColors.warning.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Historique
// ─────────────────────────────────────────────────────────────────────────────

class CovoiturageHistoryPage extends StatelessWidget {
  const CovoiturageHistoryPage({
    super.key,
    required this.trips,
    this.title = 'Historique',
    this.emptyLabel = 'Aucun trajet passé',
  });
  final List<Trip> trips;
  final String title;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: trips.isEmpty
          ? Center(
              child: Text(emptyLabel,
                  style: const TextStyle(color: AppColors.gray400)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TripCard(
                  trip: trips[i],
                  isHistory: true,
                  onTap: () => context.push(
                      '/covoiturage/trips/${trips[i].id}/detail',
                      extra: trips[i]),
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cartes trajets
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.mobiliBlue.withValues(alpha: 0.3), width: 1.5),
          boxShadow: AppColors.shadowSm,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(trip.departureCity,
                      style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.mobiliBlueDeep,
                          fontWeight: FontWeight.w800)),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.mobiliBlue, size: 18),
                Expanded(
                  child: Text(trip.arrivalCity,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.mobiliBlueDeep,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.gray100, height: 1),
            const SizedBox(height: 8),
            Text(trip.formattedDepartureFull,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.gray500)),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatusPill(status: trip.status ?? 'PROGRAMMÉ'),
                const Spacer(),
                Icon(Icons.people_outline_rounded,
                    size: 14, color: AppColors.gray400),
                const SizedBox(width: 4),
                Text(
                  bookedSeats > 0
                      ? '$bookedSeats réservé(s)'
                      : 'Aucune réservation',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.gray500, fontSize: 12),
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
  const _TripCard(
      {required this.trip, required this.onTap, this.isHistory = false});
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
                  color: isHistory ? AppColors.gray400 : AppColors.mobiliBlue,
                  size: 20),
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
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.gray400)),
                  if (bookedSeats > 0)
                    Text('$bookedSeats réservé(s) · ${trip.formattedPrice}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.gray400, fontSize: 11)),
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
              const Icon(Icons.history_rounded,
                  color: AppColors.mobiliBlue, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Historique des trajets',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.mobiliBlueDeep,
                        fontSize: 14)),
              ),
              if (count > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('$count',
                      style: const TextStyle(
                          color: AppColors.gray500,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
            ],
          ),
        ),
      );
}

class _AllTripsLink extends StatelessWidget {
  const _AllTripsLink({required this.count, required this.onTap});
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
              const Icon(Icons.list_alt_rounded,
                  color: AppColors.mobiliBlue, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Tous mes trajets',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.mobiliBlueDeep,
                        fontSize: 14)),
              ),
              if (count > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.mobiliBlueFog,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('$count',
                      style: const TextStyle(
                          color: AppColors.mobiliBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
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
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w700)),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mobiliBlueDeep)),
        ],
      );
}
