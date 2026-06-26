import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobilipro/features/dashboard/presentation/pages/dashboard_chauffeur_page.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/qr_scanner_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Utilitaire statut ticket (global au fichier)
// ─────────────────────────────────────────────────────────────────────────────

(String, Color) ticketStatusConfig(String status) {
  switch (status.toUpperCase()) {
    case 'VALIDÉ':
    case 'VALIDE':
      return ('Non présenté', AppColors.gray400);
    case 'UTILISÉ':
    case 'UTILISE':
      return ('À bord', AppColors.stationGreen);
    case 'ARRIVÉ':
    case 'ARRIVE':
      return ('Arrivé', AppColors.mobiliBlue);
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
  });
  final String passengerName;
  final String seatNumber;
  final String reference;
  final String ticketStatus;
  final String boardingCity;
  final String alightingCity;
}

class _StopPassenger {
  const _StopPassenger({
    required this.ticketNumber,
    required this.passengerName,
    required this.seatNumber,
    required this.ticketStatus,
    required this.boardingStopIndex,
  });
  final String ticketNumber;
  final String passengerName;
  final String seatNumber;
  final String ticketStatus;
  final int boardingStopIndex;

  factory _StopPassenger.fromJson(Map<String, dynamic> json) => _StopPassenger(
    ticketNumber: json['ticketNumber'] as String? ?? '',
    passengerName: json['passengerName'] as String? ?? '',
    seatNumber: json['seatNumber'] as String? ?? '',
    ticketStatus: json['ticketStatus'] as String? ?? '',
    boardingStopIndex: (json['boardingStopIndex'] as num?)?.toInt() ?? 0,
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

// Utilise GET /tickets/trip/{tripId} → statuts tickets réels
final _tripPassengersProvider = FutureProvider.autoDispose
    .family<List<_PassengerLine>, int>((ref, tripId) async {
      final dio = ApiClient.instance.dio;
      final res = await dio.get<List<dynamic>>('/tickets/trip/$tripId');
      return (res.data ?? []).map((e) {
        final json = e as Map<String, dynamic>;
        return _PassengerLine(
          passengerName: json['passengerFullName'] as String? ?? '',
          seatNumber: json['seatNumber'] as String? ?? '—',
          reference: json['ticketNumber'] as String? ?? '',
          ticketStatus: json['status'] as String? ?? '',
          boardingCity: json['boardingCity'] as String? ?? '',
          alightingCity: json['alightingCity'] as String? ?? '',
        );
      }).toList();
    });

final _boardingsProvider = FutureProvider.autoDispose
    .family<List<_StopPassenger>, ({int tripId, int stopIndex})>((
      ref,
      params,
    ) async {
      final dio = ApiClient.instance.dio;
      final res = await dio.get<List<dynamic>>(
        '/trips/${params.tripId}/driver/stops/${params.stopIndex}/boardings',
      );
      return (res.data ?? [])
          .map((e) => _StopPassenger.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final _alightingsProvider = FutureProvider.autoDispose
    .family<List<_StopPassenger>, ({int tripId, int stopIndex})>((
      ref,
      params,
    ) async {
      final dio = ApiClient.instance.dio;
      final res = await dio.get<List<dynamic>>(
        '/trips/${params.tripId}/driver/stops/${params.stopIndex}/alightings',
      );
      return (res.data ?? [])
          .map((e) => _StopPassenger.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final _tripStopsProvider = FutureProvider.autoDispose
    .family<List<_TripStop>, int>((ref, tripId) async {
      final dio = ApiClient.instance.dio;
      final res = await dio.get<List<dynamic>>('/trips/$tripId/stops');
      return (res.data ?? [])
          .map((e) => _TripStop.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.stopIndex.compareTo(b.stopIndex));
    });

// ─────────────────────────────────────────────────────────────────────────────
// Page détail trajet chauffeur
// ─────────────────────────────────────────────────────────────────────────────

class TripDetailChauffeurPage extends ConsumerStatefulWidget {
  const TripDetailChauffeurPage({super.key, required this.trip});
  final ChauffeurTripItem trip;

  @override
  ConsumerState<TripDetailChauffeurPage> createState() =>
      _TripDetailChauffeurPageState();
}

class _TripDetailChauffeurPageState
    extends ConsumerState<TripDetailChauffeurPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isStarting = false;
  late ChauffeurTripItem _trip;

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

  /// Met à jour le statut affiché localement (AppBar/bandeau) ET les listes
  /// mises en cache ailleurs dans l'app (dashboard, passagers) pour que le
  /// changement soit visible partout sans devoir quitter/rouvrir la page.
  void _applyTripStatus(String status) {
    setState(() {
      _trip = ChauffeurTripItem(
        id: _trip.id,
        source: _trip.source,
        departureCity: _trip.departureCity,
        arrivalCity: _trip.arrivalCity,
        boardingPoint: _trip.boardingPoint,
        departureDateTime: _trip.departureDateTime,
        status: status,
        partnerName: _trip.partnerName,
        stationName: _trip.stationName,
        vehiculePlateNumber: _trip.vehiculePlateNumber,
        vehicleType: _trip.vehicleType,
      );
    });
    ref.invalidate(chauffeurOverviewProvider);
    ref.invalidate(_tripPassengersProvider(_trip.id));
  }

  Future<void> _startTrip() async {
    setState(() => _isStarting = true);
    try {
      await ApiClient.instance.dio.post<void>(
        '/trips/${_trip.id}/driver/start',
      );
      if (mounted) {
        _applyTripStatus('EN_COURS');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trajet démarré ✅'),
            backgroundColor: AppColors.stationGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  bool get _isCovoiturageTrip => _trip.source == 'COVOITURAGE';

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
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient.instance.dio.delete<void>('/covoiturage/trips/${_trip.id}');
      ref.invalidate(chauffeurOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trajet supprimé'), behavior: SnackBarBehavior.floating),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_trip.departureCity} → ${_trip.arrivalCity}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              _trip.formattedDate,
              style: const TextStyle(fontSize: 11, color: Color(0xCCFFFFFF)),
            ),
          ],
        ),
        actions: [
          if (_trip.isUpcoming)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _isStarting ? null : _startTrip,
                icon: _isStarting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: AppColors.mobiliBlueDeep,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: AppColors.mobiliBlueDeep,
                      ),
                label: Text(
                  _isStarting ? '...' : 'Démarrer',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mobiliYellow,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          // Modifier/Supprimer : réservé aux trajets covoiturage de
          // l'organisateur lui-même — jamais sur un trajet ASSIGNED (le
          // chauffeur compagnie ne possède pas ses trajets).
          if (_isCovoiturageTrip && !_trip.isCompleted)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: () async {
                final edited = await context.push<bool>(
                  '/covoiturage/trips/${_trip.id}/edit',
                );
                if (edited == true) {
                  ref.invalidate(chauffeurOverviewProvider);
                  ref.invalidate(_tripStopsProvider(_trip.id));
                }
              },
            ),
          if (_isCovoiturageTrip)
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded, size: 16), text: 'Passagers'),
            Tab(icon: Icon(Icons.route_rounded, size: 16), text: 'Arrêts'),
            Tab(
              icon: Icon(Icons.qr_code_scanner_rounded, size: 16),
              text: 'Scanner',
            ),
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
                _StopsTab(trip: _trip, onStatusChanged: _applyTripStatus),
                QrScannerWidget(tripId: _trip.id, showResultOverlay: true),
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
  final ChauffeurTripItem trip;

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
          if (trip.vehiculePlateNumber != null)
            _Chip(
              icon: Icons.directions_bus_rounded,
              label: trip.vehiculePlateNumber!,
              color: AppColors.mobiliBlue,
            ),
          if (trip.vehicleType != null)
            _Chip(
              icon: Icons.category_rounded,
              label: trip.vehicleType!.replaceAll('_', ' '),
              color: AppColors.gray500,
            ),
          if (trip.partnerName != null)
            _Chip(
              icon: Icons.business_rounded,
              label: trip.partnerName!,
              color: AppColors.proGold,
            ),
          _StatusBadge(status: trip.status),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet Passagers — source : /tickets/trip/{tripId} avec vrais statuts ticket
// ─────────────────────────────────────────────────────────────────────────────

class _PassengersTab extends ConsumerStatefulWidget {
  const _PassengersTab({required this.tripId});
  final int tripId;

  @override
  ConsumerState<_PassengersTab> createState() => _PassengersTabState();
}

class _PassengersTabState extends ConsumerState<_PassengersTab> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linesAsync = ref.watch(_tripPassengersProvider(widget.tripId));

    return linesAsync.when(
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
              onPressed: () =>
                  ref.invalidate(_tripPassengersProvider(widget.tripId)),
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
                  style: TextStyle(color: AppColors.gray400, fontSize: 15),
                ),
              ],
            ),
          );
        }

        final filtered = _search.isEmpty
            ? lines
            : lines.where((l) {
                final q = _search.toLowerCase();
                return l.passengerName.toLowerCase().contains(q) ||
                    l.seatNumber.toLowerCase().contains(q) ||
                    l.reference.toLowerCase().contains(q);
              }).toList();

        // Stats
        final aboard = lines
            .where(
              (l) =>
                  l.ticketStatus.toUpperCase() == 'UTILISÉ' ||
                  l.ticketStatus.toUpperCase() == 'UTILISE',
            )
            .length;
        final arrived = lines
            .where(
              (l) =>
                  l.ticketStatus.toUpperCase() == 'ARRIVÉ' ||
                  l.ticketStatus.toUpperCase() == 'ARRIVE',
            )
            .length;
        final noShow = lines
            .where(
              (l) =>
                  l.ticketStatus.toUpperCase() == 'VALIDÉ' ||
                  l.ticketStatus.toUpperCase() == 'VALIDE',
            )
            .length;

        return Column(
          children: [
            // Stats banner
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
                    label: 'Total',
                    value: '${lines.length}',
                    color: AppColors.mobiliBlue,
                  ),
                  _MiniStat(
                    label: 'À bord',
                    value: '$aboard',
                    color: AppColors.stationGreen,
                  ),
                  _MiniStat(
                    label: 'Arrivés',
                    value: '$arrived',
                    color: AppColors.mobiliBlue,
                  ),
                  _MiniStat(
                    label: 'Absents',
                    value: '$noShow',
                    color: AppColors.danger,
                  ),
                ],
              ),
            ),

            // Recherche
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Nom, siège, n° ticket...',
                    hintStyle: const TextStyle(
                      color: AppColors.gray400,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.gray400,
                      size: 18,
                    ),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 16,
                              color: AppColors.gray400,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // Liste
            Expanded(
              child: RefreshIndicator(
                color: AppColors.mobiliBlue,
                onRefresh: () async =>
                    ref.invalidate(_tripPassengersProvider(widget.tripId)),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _PassengerCard(line: filtered[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet Arrêts avec noms de villes
// ─────────────────────────────────────────────────────────────────────────────

class _StopsTab extends ConsumerStatefulWidget {
  const _StopsTab({required this.trip, required this.onStatusChanged});
  final ChauffeurTripItem trip;
  final ValueChanged<String> onStatusChanged;

  @override
  ConsumerState<_StopsTab> createState() => _StopsTabState();
}

class _StopsTabState extends ConsumerState<_StopsTab> {
  int _currentStop = 0;
  bool _isRecordingDeparture = false;
  bool _tripEnded = false;

  Future<void> _recordDeparture(String cityLabel, bool isLast) async {
    setState(() => _isRecordingDeparture = true);
    try {
      await ApiClient.instance.dio.post<void>(
        '/trips/${widget.trip.id}/driver/departures',
        data: {'stopIndex': _currentStop},
      );
      if (mounted) {
        widget.onStatusChanged(isLast ? 'TERMINÉ' : 'EN_COURS');
        if (isLast) {
          setState(() => _tripEnded = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trajet terminé 🏁'),
              backgroundColor: AppColors.stationGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Départ de $cityLabel enregistré ✅'),
              backgroundColor: AppColors.stationGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _currentStop++);
          _refreshStop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecordingDeparture = false);
    }
  }

  Future<void> _undoLastDeparture() async {
    setState(() => _isRecordingDeparture = true);
    try {
      final res = await ApiClient.instance.dio.post<Map<String, dynamic>>(
        '/trips/${widget.trip.id}/driver/departures/undo',
      );
      final newCurrentStop = res.data?['currentStopIndex'] as int? ?? 0;
      if (mounted) {
        setState(() {
          _currentStop = newCurrentStop;
          _tripEnded = false;
        });
        widget.onStatusChanged(newCurrentStop == 0 ? 'PROGRAMMÉ' : 'EN_COURS');
        _refreshStop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dernier départ annulé'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecordingDeparture = false);
    }
  }

  void _refreshStop() {
    ref.invalidate(
      _boardingsProvider((tripId: widget.trip.id, stopIndex: _currentStop)),
    );
    ref.invalidate(
      _alightingsProvider((tripId: widget.trip.id, stopIndex: _currentStop)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stopsAsync = ref.watch(_tripStopsProvider(widget.trip.id));
    final boardingsAsync = ref.watch(
      _boardingsProvider((tripId: widget.trip.id, stopIndex: _currentStop)),
    );
    final alightingsAsync = ref.watch(
      _alightingsProvider((tripId: widget.trip.id, stopIndex: _currentStop)),
    );

    return stopsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.mobiliBlue),
      ),
      error: (e, _) => Center(
        child: Text(
          'Erreur stops : $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (stops) {
        final currentStopObj = stops
            .where((s) => s.stopIndex == _currentStop)
            .firstOrNull;
        final currentStopName =
            currentStopObj?.cityLabel ?? 'Arrêt $_currentStop';
        final maxStop = stops.isNotEmpty
            ? stops.map((s) => s.stopIndex).reduce((a, b) => a > b ? a : b)
            : 0;
        final isLastStop = _currentStop == maxStop;

        return Column(
          children: [
            // ── Sélecteur arrêt avec nom ville ──────
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _currentStop > 0
                        ? () {
                            setState(() => _currentStop--);
                            _refreshStop();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: _currentStop > 0
                        ? AppColors.mobiliBlue
                        : AppColors.gray300,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          currentStopName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.mobiliBlueDeep,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _tripEnded
                              ? 'Trajet terminé 🏁'
                              : 'Arrêt $_currentStop / $maxStop',
                          style: TextStyle(
                            fontSize: 11,
                            color: _tripEnded
                                ? AppColors.stationGreen
                                : AppColors.gray400,
                            fontWeight: _tripEnded
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxStop > 0 ? _currentStop / maxStop : 0,
                            backgroundColor: AppColors.gray200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _tripEnded
                                  ? AppColors.stationGreen
                                  : AppColors.mobiliBlue,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLastStop && !_tripEnded)
                    IconButton(
                      onPressed: () {
                        setState(() => _currentStop++);
                        _refreshStop();
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: AppColors.mobiliBlue,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Contenu ─────────────────────────────
            Expanded(
              child: _tripEnded
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.stationGreen.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flag_rounded,
                              color: AppColors.stationGreen,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Trajet terminé !',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mobiliBlueDeep,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Arrivée à $currentStopName enregistrée.',
                            style: const TextStyle(
                              color: AppColors.gray500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: _isRecordingDeparture
                                ? null
                                : _undoLastDeparture,
                            icon: const Icon(
                              Icons.undo_rounded,
                              size: 16,
                              color: AppColors.gray500,
                            ),
                            label: const Text(
                              'Annuler (clic par erreur)',
                              style: TextStyle(color: AppColors.gray500),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.mobiliBlue,
                      onRefresh: () async => _refreshStop(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const _SectionHeader(
                            icon: Icons.login_rounded,
                            label: 'Passagers qui montent',
                            color: AppColors.stationGreen,
                          ),
                          const SizedBox(height: 8),
                          boardingsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.mobiliBlue,
                              ),
                            ),
                            error: (e, _) => Text(
                              'Erreur : $e',
                              style: const TextStyle(color: AppColors.danger),
                            ),
                            data: (boardings) => boardings.isEmpty
                                ? const _EmptyStop(
                                    label: 'Aucun montant à cet arrêt',
                                  )
                                : Column(
                                    children: boardings
                                        .map(
                                          (p) => _StopPassengerCard(
                                            passenger: p,
                                            isBoarding: true,
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(
                            icon: Icons.logout_rounded,
                            label: 'Passagers qui descendent',
                            color: AppColors.warning,
                          ),
                          const SizedBox(height: 8),
                          alightingsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.mobiliBlue,
                              ),
                            ),
                            error: (e, _) => Text(
                              'Erreur : $e',
                              style: const TextStyle(color: AppColors.danger),
                            ),
                            data: (alightings) => alightings.isEmpty
                                ? const _EmptyStop(
                                    label: 'Aucun descendant à cet arrêt',
                                  )
                                : Column(
                                    children: alightings
                                        .map(
                                          (p) => _StopPassengerCard(
                                            passenger: p,
                                            isBoarding: false,
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isRecordingDeparture
                                  ? null
                                  : () => _recordDeparture(
                                      currentStopName,
                                      isLastStop,
                                    ),
                              icon: _isRecordingDeparture
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isLastStop
                                          ? Icons.flag_rounded
                                          : Icons.directions_bus_rounded,
                                      size: 18,
                                    ),
                              label: Text(
                                _isRecordingDeparture
                                    ? 'Enregistrement...'
                                    : isLastStop
                                    ? 'Terminer le trajet'
                                    : 'Quitter $currentStopName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isLastStop
                                    ? AppColors.danger
                                    : AppColors.mobiliBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: TextButton.icon(
                              onPressed: _isRecordingDeparture
                                  ? null
                                  : _undoLastDeparture,
                              icon: const Icon(
                                Icons.undo_rounded,
                                size: 14,
                                color: AppColors.gray400,
                              ),
                              label: const Text(
                                'Annuler le dernier départ',
                                style: TextStyle(
                                  color: AppColors.gray400,
                                  fontSize: 12,
                                ),
                              ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Carte passager (onglet passagers) — badge statut ticket réel
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.line});
  final _PassengerLine line;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = ticketStatusConfig(line.ticketStatus);

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
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                line.passengerName.isNotEmpty
                    ? line.passengerName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Infos
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
          const SizedBox(width: 8),
          // Siège + statut
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
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

// ─────────────────────────────────────────────────────────────────────────────
// Carte passager arrêt (montant / descendant)
// ─────────────────────────────────────────────────────────────────────────────

class _StopPassengerCard extends StatelessWidget {
  const _StopPassengerCard({required this.passenger, required this.isBoarding});
  final _StopPassenger passenger;
  final bool isBoarding;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = ticketStatusConfig(
      passenger.ticketStatus,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBoarding
              ? AppColors.stationGreen.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isBoarding
                  ? AppColors.stationGreen.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBoarding ? Icons.login_rounded : Icons.logout_rounded,
              size: 18,
              color: isBoarding ? AppColors.stationGreen : AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passenger.passengerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                Text(
                  'Siège ${passenger.seatNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
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
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );
}

class _EmptyStop extends StatelessWidget {
  const _EmptyStop({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.gray100,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: AppColors.gray400,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.gray400, fontSize: 13),
        ),
      ],
    ),
  );
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
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
