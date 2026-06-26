import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/qr_scanner_widget.dart';
import '../../../trips/domain/models/trip.dart';
import '../../providers/covoiturage_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Statut billet (à bord / non présenté / arrivé) — partagé avec les cartes
// ─────────────────────────────────────────────────────────────────────────────

(String, Color) ticketStatusConfig(String status) {
  switch (status.toUpperCase()) {
    case 'VALIDÉ':
    case 'VALIDE':
      return ('Non présenté', AppColors.gray400);
    case 'UTILISÉ':
    case 'UTILISE':
      return ('À bord', AppColors.success);
    case 'ARRIVÉ':
    case 'ARRIVE':
      return ('Arrivé', AppColors.mobiliBlue);
    case 'ANNULÉ':
    case 'ANNULE':
      return ('Annulé', AppColors.danger);
    default:
      return (status, AppColors.gray400);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerLine {
  const _PassengerLine({
    required this.passengerName,
    required this.seatNumber,
    required this.reference,
    required this.ticketStatus,
    required this.boardingCity,
    required this.alightingCity,
    required this.price,
  });
  final String passengerName;
  final String seatNumber;
  final String reference;
  final String ticketStatus;
  final String boardingCity;
  final String alightingCity;
  final double price;

  factory _PassengerLine.fromJson(Map<String, dynamic> json) => _PassengerLine(
        passengerName: json['passengerFullName'] as String? ?? '',
        seatNumber: json['seatNumber'] as String? ?? '—',
        reference: json['ticketNumber'] as String? ?? '',
        ticketStatus: json['status'] as String? ?? '',
        boardingCity: json['boardingCity'] as String? ?? '',
        alightingCity: json['alightingCity'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
      );
}

class _StopPassenger {
  const _StopPassenger({
    required this.passengerName,
    required this.seatNumber,
    required this.ticketStatus,
  });
  final String passengerName;
  final String seatNumber;
  final String ticketStatus;

  factory _StopPassenger.fromJson(Map<String, dynamic> json) => _StopPassenger(
        passengerName: json['passengerName'] as String? ?? '',
        seatNumber: json['seatNumber'] as String? ?? '',
        ticketStatus: json['ticketStatus'] as String? ?? '',
      );
}

class _TripStop {
  const _TripStop({required this.stopIndex, required this.cityLabel});
  final int stopIndex;
  final String cityLabel;

  factory _TripStop.fromJson(Map<String, dynamic> json) => _TripStop(
        stopIndex: (json['stopIndex'] as num).toInt(),
        cityLabel: json['cityLabel'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _tripPassengersProvider = FutureProvider.autoDispose
    .family<List<_PassengerLine>, int>((ref, tripId) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>('/tickets/trip/$tripId');
  return (res.data ?? [])
      .map((e) => _PassengerLine.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _boardingsProvider = FutureProvider.autoDispose
    .family<List<_StopPassenger>, ({int tripId, int stopIndex})>((ref, p) async {
  final res = await ApiClient.instance.dio
      .get<List<dynamic>>('/trips/${p.tripId}/driver/stops/${p.stopIndex}/boardings');
  return (res.data ?? [])
      .map((e) => _StopPassenger.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _alightingsProvider = FutureProvider.autoDispose
    .family<List<_StopPassenger>, ({int tripId, int stopIndex})>((ref, p) async {
  final res = await ApiClient.instance.dio
      .get<List<dynamic>>('/trips/${p.tripId}/driver/stops/${p.stopIndex}/alightings');
  return (res.data ?? [])
      .map((e) => _StopPassenger.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _tripStopsProvider =
    FutureProvider.autoDispose.family<List<_TripStop>, int>((ref, tripId) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>('/trips/$tripId/stops');
  return (res.data ?? [])
      .map((e) => _TripStop.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => a.stopIndex.compareTo(b.stopIndex));
});

// ─────────────────────────────────────────────────────────────────────────────
// Page — fusion partenaire (modifier/supprimer) + gare (passagers/paiement) +
// chauffeur (démarrer, arrêts, scanner)
// ─────────────────────────────────────────────────────────────────────────────

class CovoiturageTripDetailPage extends ConsumerStatefulWidget {
  const CovoiturageTripDetailPage({super.key, required this.trip});
  final Trip trip;

  @override
  ConsumerState<CovoiturageTripDetailPage> createState() =>
      _CovoiturageTripDetailPageState();
}

class _CovoiturageTripDetailPageState
    extends ConsumerState<CovoiturageTripDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Trip _trip;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _startTrip() async {
    setState(() => _isStarting = true);
    try {
      await ApiClient.instance.dio.post<void>('/trips/${_trip.id}/driver/start');
      if (mounted) {
        setState(() {
          _trip = Trip(
            id: _trip.id,
            departureCity: _trip.departureCity,
            arrivalCity: _trip.arrivalCity,
            departureTime: _trip.departureTime,
            arrivalTime: _trip.arrivalTime,
            totalSeats: _trip.totalSeats,
            availableSeats: _trip.availableSeats,
            priceXof: _trip.priceXof,
            transportType: _trip.transportType,
            partnerName: _trip.partnerName,
            legFares: _trip.legFares,
            vehicleImageUrl: _trip.vehicleImageUrl,
            moreInfo: _trip.moreInfo,
            boardingPoint: _trip.boardingPoint,
            vehicleType: _trip.vehicleType,
            extraHoldBagPrice: _trip.extraHoldBagPrice,
            maxExtraHoldBagsPerPassenger: _trip.maxExtraHoldBagsPerPassenger,
            status: 'EN_COURS',
          );
        });
        ref.invalidate(myCovoiturageTripsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trajet démarré ✅'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce trajet ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await ref.read(covoiturageTripNotifierProvider.notifier).delete(_trip.id);
      if (ok && mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Text('${_trip.departureCity} → ${_trip.arrivalCity}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        actions: [
          if (_trip.isUpcoming)
            IconButton(
              icon: _isStarting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              tooltip: 'Démarrer',
              onPressed: _isStarting ? null : _startTrip,
            ),
          if (!_trip.isCompleted)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: () => context.push('/covoiturage/trips/${_trip.id}/edit', extra: _trip),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Supprimer',
            onPressed: _confirmDelete,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.mobiliYellow,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded, size: 16), text: 'Passagers'),
            Tab(icon: Icon(Icons.route_rounded, size: 16), text: 'Arrêts'),
            Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 16), text: 'Scanner'),
          ],
        ),
      ),
      body: Column(
        children: [
          _TripInfoBanner(trip: _trip),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PassengersTab(tripId: _trip.id),
                _StopsTab(trip: _trip),
                const QrScannerWidget(showResultOverlay: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bandeau infos trajet
// ─────────────────────────────────────────────────────────────────────────────

class _TripInfoBanner extends StatelessWidget {
  const _TripInfoBanner({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (trip.vehicleTypeLabel.isNotEmpty)
            _Chip(icon: Icons.category_rounded, label: trip.vehicleTypeLabel, color: AppColors.gray500),
          _Chip(icon: Icons.payments_rounded, label: trip.formattedPrice, color: AppColors.mobiliBlue),
          _StatusBadge(status: trip.status ?? 'PROGRAMMÉ'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet Passagers
// ─────────────────────────────────────────────────────────────────────────────

class _PassengersTab extends ConsumerWidget {
  const _PassengersTab({required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linesAsync = ref.watch(_tripPassengersProvider(tripId));

    return linesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
      data: (lines) {
        if (lines.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 48, color: AppColors.gray300),
                  SizedBox(height: 12),
                  Text('Aucun passager pour le moment',
                      style: TextStyle(color: AppColors.gray400, fontSize: 15)),
                ],
              ),
            ),
          );
        }

        final aboard = lines.where((l) => l.ticketStatus.toUpperCase().startsWith('UTILIS')).length;
        final arrived = lines.where((l) => l.ticketStatus.toUpperCase().startsWith('ARRIV')).length;
        final revenue = lines
            .where((l) => !l.ticketStatus.toUpperCase().startsWith('ANNUL'))
            .fold(0.0, (s, l) => s + l.price);

        return RefreshIndicator(
          color: AppColors.mobiliBlue,
          onRefresh: () async => ref.invalidate(_tripPassengersProvider(tripId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mobiliBlueFog,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat(label: 'Total', value: '${lines.length}', color: AppColors.mobiliBlue),
                    _MiniStat(label: 'À bord', value: '$aboard', color: AppColors.success),
                    _MiniStat(label: 'Arrivés', value: '$arrived', color: AppColors.mobiliBlue),
                    _MiniStat(
                      label: 'Revenus',
                      value: '${revenue.toStringAsFixed(0)} F',
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...lines.map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PassengerCard(line: l),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.line});
  final _PassengerLine line;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = ticketStatusConfig(line.ticketStatus);

    return Container(
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
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                line.passengerName.isNotEmpty ? line.passengerName[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.passengerName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w700,
                    )),
                if (line.boardingCity.isNotEmpty)
                  Text('${line.boardingCity} → ${line.alightingCity}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.mobiliBlue, fontSize: 11)),
                Text('${line.price.toStringAsFixed(0)} FCFA',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mobiliBlueDeep,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Siège ${line.seatNumber}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(statusLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet Arrêts
// ─────────────────────────────────────────────────────────────────────────────

class _StopsTab extends ConsumerStatefulWidget {
  const _StopsTab({required this.trip});
  final Trip trip;

  @override
  ConsumerState<_StopsTab> createState() => _StopsTabState();
}

class _StopsTabState extends ConsumerState<_StopsTab> {
  int _currentStop = 0;
  bool _isRecording = false;
  bool _tripEnded = false;

  void _refresh() {
    ref.invalidate(_boardingsProvider((tripId: widget.trip.id, stopIndex: _currentStop)));
    ref.invalidate(_alightingsProvider((tripId: widget.trip.id, stopIndex: _currentStop)));
  }

  Future<void> _recordDeparture(String cityLabel, bool isLast) async {
    setState(() => _isRecording = true);
    try {
      await ApiClient.instance.dio.post<void>(
        '/trips/${widget.trip.id}/driver/departures',
        data: {'stopIndex': _currentStop},
      );
      if (mounted) {
        if (isLast) {
          setState(() => _tripEnded = true);
        } else {
          setState(() => _currentStop++);
          _refresh();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isLast ? 'Trajet terminé 🏁' : 'Départ de $cityLabel enregistré ✅'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _undoLastDeparture() async {
    setState(() => _isRecording = true);
    try {
      final res = await ApiClient.instance.dio
          .post<Map<String, dynamic>>('/trips/${widget.trip.id}/driver/departures/undo');
      final newCurrentStop = res.data?['currentStopIndex'] as int? ?? 0;
      if (mounted) {
        setState(() {
          _currentStop = newCurrentStop;
          _tripEnded = false;
        });
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dernier départ annulé'), backgroundColor: AppColors.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopsAsync = ref.watch(_tripStopsProvider(widget.trip.id));
    final boardingsAsync =
        ref.watch(_boardingsProvider((tripId: widget.trip.id, stopIndex: _currentStop)));
    final alightingsAsync =
        ref.watch(_alightingsProvider((tripId: widget.trip.id, stopIndex: _currentStop)));

    return stopsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
      data: (stops) {
        final currentStopObj = stops.where((s) => s.stopIndex == _currentStop).firstOrNull;
        final currentStopName = currentStopObj?.cityLabel ?? 'Arrêt $_currentStop';
        final maxStop =
            stops.isNotEmpty ? stops.map((s) => s.stopIndex).reduce((a, b) => a > b ? a : b) : 0;
        final isLastStop = _currentStop == maxStop;

        return Column(
          children: [
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _currentStop > 0
                        ? () {
                            setState(() => _currentStop--);
                            _refresh();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: _currentStop > 0 ? AppColors.mobiliBlue : AppColors.gray300,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(currentStopName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.mobiliBlueDeep),
                            textAlign: TextAlign.center),
                        Text(
                          _tripEnded ? 'Trajet terminé 🏁' : 'Arrêt $_currentStop / $maxStop',
                          style: TextStyle(
                            fontSize: 11,
                            color: _tripEnded ? AppColors.success : AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLastStop && !_tripEnded)
                    IconButton(
                      onPressed: () {
                        setState(() => _currentStop++);
                        _refresh();
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: AppColors.mobiliBlue,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _tripEnded
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flag_rounded, color: AppColors.success, size: 48),
                          const SizedBox(height: 12),
                          const Text('Trajet terminé !',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.mobiliBlueDeep)),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _isRecording ? null : _undoLastDeparture,
                            icon: const Icon(Icons.undo_rounded, size: 16, color: AppColors.gray500),
                            label: const Text('Annuler (clic par erreur)',
                                style: TextStyle(color: AppColors.gray500)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.mobiliBlue,
                      onRefresh: () async => _refresh(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const _SectionHeader(
                              icon: Icons.login_rounded, label: 'Passagers qui montent', color: AppColors.success),
                          const SizedBox(height: 8),
                          boardingsAsync.when(
                            loading: () =>
                                const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
                            error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
                            data: (boardings) => boardings.isEmpty
                                ? const _EmptyStop(label: 'Aucun montant à cet arrêt')
                                : Column(children: boardings.map((p) => _StopPassengerCard(passenger: p, isBoarding: true)).toList()),
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(
                              icon: Icons.logout_rounded, label: 'Passagers qui descendent', color: AppColors.warning),
                          const SizedBox(height: 8),
                          alightingsAsync.when(
                            loading: () =>
                                const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
                            error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.danger)),
                            data: (alightings) => alightings.isEmpty
                                ? const _EmptyStop(label: 'Aucun descendant à cet arrêt')
                                : Column(children: alightings.map((p) => _StopPassengerCard(passenger: p, isBoarding: false)).toList()),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isRecording
                                  ? null
                                  : () => _recordDeparture(currentStopName, isLastStop),
                              icon: _isRecording
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Icon(isLastStop ? Icons.flag_rounded : Icons.directions_car_rounded, size: 18),
                              label: Text(
                                _isRecording
                                    ? 'Enregistrement...'
                                    : isLastStop
                                        ? 'Terminer le trajet'
                                        : 'Quitter $currentStopName',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isLastStop ? AppColors.danger : AppColors.mobiliBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          Center(
                            child: TextButton.icon(
                              onPressed: _isRecording ? null : _undoLastDeparture,
                              icon: const Icon(Icons.undo_rounded, size: 14, color: AppColors.gray400),
                              label: const Text('Annuler le dernier départ',
                                  style: TextStyle(color: AppColors.gray400, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StopPassengerCard extends StatelessWidget {
  const _StopPassengerCard({required this.passenger, required this.isBoarding});
  final _StopPassenger passenger;
  final bool isBoarding;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = ticketStatusConfig(passenger.ticketStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBoarding
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(isBoarding ? Icons.login_rounded : Icons.logout_rounded,
              size: 18, color: isBoarding ? AppColors.success : AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(passenger.passengerName,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.mobiliBlueDeep, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('Siège ${passenger.seatNumber}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray500, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

class _EmptyStop extends StatelessWidget {
  const _EmptyStop({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.gray400),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.gray400, fontSize: 13)),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status.toUpperCase()) {
      'EN_COURS' => ('En cours', AppColors.successSoft, AppColors.success),
      'PROGRAMMÉ' || 'PROGRAMME' => ('Programmé', AppColors.mobiliBlueFog, AppColors.mobiliBlue),
      'TERMINÉ' || 'TERMINE' => ('Terminé', AppColors.gray100, AppColors.gray500),
      'ANNULÉ' || 'ANNULE' => ('Annulé', AppColors.dangerSoft, AppColors.danger),
      _ => (status, AppColors.gray100, AppColors.gray500),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.gray500)),
        ],
      );
}
