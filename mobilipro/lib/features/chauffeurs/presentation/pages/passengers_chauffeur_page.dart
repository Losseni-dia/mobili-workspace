import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/features/dashboard/presentation/pages/dashboard_chauffeur_page.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/qr_scanner_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page Passagers Chauffeur
// Liste les trajets du chauffeur → tap → voir passagers + scanner QR
// ─────────────────────────────────────────────────────────────────────────────

class PassagersChauffeurPage extends ConsumerWidget {
  const PassagersChauffeurPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(chauffeurOverviewProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Passagers',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(chauffeurOverviewProvider),
          ),
        ],
      ),
      body: overviewAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                style: const TextStyle(color: AppColors.gray500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(chauffeurOverviewProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mobiliBlue,
                ),
                child: const Text(
                  'Réessayer',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        data: (overview) {
          final allTrips = [...overview.upcoming, ...overview.history];

          if (allTrips.isEmpty) {
            return Center(
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
                    child: const Icon(
                      Icons.people_outline_rounded,
                      color: AppColors.mobiliBlue,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Aucun trajet assigné',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mobiliBlueDeep,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.mobiliBlue,
            onRefresh: () async => ref.invalidate(chauffeurOverviewProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allTrips.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TripPassengerCard(
                  trip: allTrips[i],
                  onShowPassengers: () => _showPassengers(context, allTrips[i]),
                  onScanQr: () => _showScanner(context, allTrips[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPassengers(BuildContext context, ChauffeurTripItem trip) {
    // Réutilise PassengersSheet en adaptant via un TripItem minimal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChauffeurPassengersSheet(trip: trip),
    );
  }

  void _showScanner(BuildContext context, ChauffeurTripItem trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScannerSheet(trip: trip),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card trajet avec actions passagers + scanner
// ─────────────────────────────────────────────────────────────────────────────

class _TripPassengerCard extends StatelessWidget {
  const _TripPassengerCard({
    required this.trip,
    required this.onShowPassengers,
    required this.onScanQr,
  });
  final ChauffeurTripItem trip;
  final VoidCallback onShowPassengers;
  final VoidCallback onScanQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            trip.departureCity,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.mobiliYellow,
                              size: 14,
                            ),
                          ),
                          Text(
                            trip.arrivalCity,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        trip.formattedDate,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: trip.status),
              ],
            ),
          ),

          // Infos véhicule
          if (trip.vehiculePlateNumber != null || trip.vehicleType != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_bus_rounded,
                    size: 14,
                    color: AppColors.gray400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    [
                      trip.vehicleType,
                      trip.vehiculePlateNumber,
                    ].where((e) => e != null && e.isNotEmpty).join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.people_rounded,
                    label: 'Voir passagers',
                    color: AppColors.mobiliBlue,
                    onTap: onShowPassengers,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scanner QR',
                    color: AppColors.stationGreen,
                    onTap: onScanQr,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet passagers chauffeur (wrapper autour de PassengersSheet)
// ─────────────────────────────────────────────────────────────────────────────

class _ChauffeurPassengersSheet extends ConsumerWidget {
  const _ChauffeurPassengersSheet({required this.trip});
  final ChauffeurTripItem trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengersAsync = ref.watch(_passengersLinesProvider(trip.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Passagers',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mobiliBlueDeep,
                        ),
                      ),
                      Text(
                        '${trip.departureCity} → ${trip.arrivalCity}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.gray400,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.gray100),
          Expanded(
            child: passengersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (lines) {
                if (lines.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: AppColors.gray300,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Aucun passager confirmé',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mobiliBlueFog,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MiniStat(
                            label: 'Passagers',
                            value: '${lines.length}',
                            color: AppColors.mobiliBlue,
                          ),
                          _MiniStat(
                            label: 'Revenus',
                            value:
                                '${lines.fold(0.0, (s, l) => s + l.amount).toStringAsFixed(0)} F',
                            color: AppColors.proGold,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: lines.length,
                        itemBuilder: (_, i) => _PassengerRow(line: lines[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet scanner QR
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerSheet extends StatelessWidget {
  const _ScannerSheet({required this.trip});
  final ChauffeurTripItem trip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Handle + header
          Container(
            color: AppColors.mobiliBlue,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scanner QR',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${trip.departureCity} → ${trip.arrivalCity}',
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Scanner widget
          Expanded(
            child: QrScannerWidget(tripId: trip.id, showResultOverlay: true),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider passagers (réutilisé depuis passengers_sheet)
// ─────────────────────────────────────────────────────────────────────────────

final _passengersLinesProvider = FutureProvider.autoDispose
    .family<List<_PassengerLine>, int>((ref, tripId) async {
      final dio = ApiClient.instance.dio;
      final response = await dio.get<List<dynamic>>(
        '/bookings/trips/$tripId/passengers',
      );
      final lines = <_PassengerLine>[];
      for (final e in response.data ?? []) {
        final json = e as Map<String, dynamic>;
        final reference = json['reference'] as String? ?? '';
        final status = json['status'] as String? ?? '';
        final amount = (json['amount'] as num?)?.toDouble() ?? 0;
        final boardingCity = json['boardingCity'] as String? ?? '';
        final alightingCity = json['alightingCity'] as String? ?? '';
        final passengerNames = (json['passengerNames'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList();
        final seatNumbers = (json['seatNumbers'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList();
        for (int i = 0; i < passengerNames.length; i++) {
          lines.add(
            _PassengerLine(
              passengerName: passengerNames[i],
              seatNumber: i < seatNumbers.length ? seatNumbers[i] : '—',
              reference: reference,
              status: status,
              amount:
                  amount /
                  (passengerNames.isNotEmpty ? passengerNames.length : 1),
              boardingCity: boardingCity,
              alightingCity: alightingCity,
            ),
          );
        }
      }
      return lines;
    });

class _PassengerLine {
  const _PassengerLine({
    required this.passengerName,
    required this.seatNumber,
    required this.reference,
    required this.status,
    required this.amount,
    required this.boardingCity,
    required this.alightingCity,
  });
  final String passengerName;
  final String seatNumber;
  final String reference;
  final String status;
  final double amount;
  final String boardingCity;
  final String alightingCity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({required this.line});
  final _PassengerLine line;

  @override
  Widget build(BuildContext context) {
    final isOffline = line.status == 'OFFLINE_SALE';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOffline
                  ? AppColors.mobiliBlueFog
                  : const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                line.passengerName.isNotEmpty
                    ? line.passengerName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isOffline
                      ? AppColors.mobiliBlue
                      : AppColors.stationGreen,
                  fontSize: 18,
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
                  line.passengerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                if (line.boardingCity.isNotEmpty)
                  Text(
                    '${line.boardingCity} → ${line.alightingCity}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mobiliBlue,
                    ),
                  ),
                Text(
                  line.reference,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.mobiliBlueDeep,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Siège ${line.seatNumber}',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
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

  (String, Color, Color) _config(String s) {
    switch (s.toUpperCase()) {
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
      default:
        return (s, AppColors.gray100, AppColors.gray500);
    }
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: color,
          fontSize: 16,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.gray500),
      ),
    ],
  );
}
