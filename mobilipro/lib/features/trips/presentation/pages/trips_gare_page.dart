import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/features/trips/presentation/widgets/offline_sale_sheet.dart';
import 'package:mobilipro/features/trips/presentation/widgets/passengers_sheet.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/search_filter_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────────────────────

class TripItem {
  const TripItem({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.boardingPoint,
    required this.departureDateTime,
    required this.price,
    required this.totalSeats,
    required this.availableSeats,
    required this.status,
    required this.vehicleType,
    required this.vehiculePlateNumber,
    this.vehicleImageUrl,
    this.moreInfo,
    this.assignedChauffeurFirstname,
    this.assignedChauffeurLastname,
    this.stationName,
    this.stationId,
  });

  final int id;
  final String departureCity;
  final String arrivalCity;
  final String boardingPoint;
  final DateTime departureDateTime;
  final double price;
  final int totalSeats;
  final int availableSeats;
  final String status;
  final String vehicleType;
  final String vehiculePlateNumber;
  final String? vehicleImageUrl;
  final String? moreInfo;
  final String? assignedChauffeurFirstname;
  final String? assignedChauffeurLastname;
  final String? stationName;
  final int? stationId;

  String get chauffeurName {
    if (assignedChauffeurFirstname == null) return 'Non assigné';
    return '$assignedChauffeurFirstname $assignedChauffeurLastname'.trim();
  }

  bool get hasChauffeur => assignedChauffeurFirstname != null;

  int get occupancyRate =>
      totalSeats > 0 ? ((totalSeats - availableSeats) * 100 ~/ totalSeats) : 0;

  factory TripItem.fromJson(Map<String, dynamic> json) => TripItem(
    id: json['id'] as int,
    departureCity: json['departureCity'] as String? ?? '',
    arrivalCity: json['arrivalCity'] as String? ?? '',
    boardingPoint: json['boardingPoint'] as String? ?? '',
    departureDateTime:
        DateTime.tryParse(json['departureDateTime'] as String? ?? '') ??
        DateTime.now(),
    price: (json['price'] as num?)?.toDouble() ?? 0,
    totalSeats: (json['totalSeats'] as num?)?.toInt() ?? 0,
    availableSeats: (json['availableSeats'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? '',
    vehicleType: json['vehicleType'] as String? ?? '',
    vehiculePlateNumber: json['vehiculePlateNumber'] as String? ?? '',
    vehicleImageUrl: json['vehicleImageUrl'] as String?,
    moreInfo: json['moreInfo'] as String?,
    assignedChauffeurFirstname: json['assignedChauffeurFirstname'] as String?,
    assignedChauffeurLastname: json['assignedChauffeurLastname'] as String?,
    stationName: json['stationName'] as String?,
    stationId: json['stationId'] as int?,
  );
}

class PassengerItem {
  const PassengerItem({
    required this.id,
    required this.reference,
    required this.customerName,
    required this.numberOfSeats,
    required this.amount,
    required this.status,
    required this.seatNumbers,
    required this.passengerNames,
    required this.boardingCity,
    required this.alightingCity,
  });

  final int id;
  final String reference;
  final String customerName;
  final int numberOfSeats;
  final double amount;
  final String status;
  final List<String> seatNumbers;
  final List<String> passengerNames;
  final String boardingCity;
  final String alightingCity;

  factory PassengerItem.fromJson(Map<String, dynamic> json) => PassengerItem(
    id: json['id'] as int,
    reference: json['reference'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    numberOfSeats: (json['numberOfSeats'] as num?)?.toInt() ?? 1,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    status: (json['status'] as String?) ?? '',
    seatNumbers: (json['seatNumbers'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    passengerNames: (json['passengerNames'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    boardingCity: json['boardingCity'] as String? ?? '',
    alightingCity: json['alightingCity'] as String? ?? '',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _myTripsProvider = FutureProvider.autoDispose<List<TripItem>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<List<dynamic>>('/trips/my-trips');
  return (response.data ?? [])
      .map((e) => TripItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _passengersProvider = FutureProvider.autoDispose
    .family<List<PassengerItem>, int>((ref, tripId) async {
      final dio = ApiClient.instance.dio;
      final response = await dio.get<List<dynamic>>(
        '/bookings/trips/$tripId/passengers',
      );
      return (response.data ?? [])
          .map((e) => PassengerItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

// ─────────────────────────────────────────────────────────────────────────────
// Constantes
// ─────────────────────────────────────────────────────────────────────────────

const _tripFilterItems = [
  FilterItem(value: 'TOUS', label: 'Tous'),
  FilterItem(value: 'PROGRAMMÉ', label: 'Programmé'),
  FilterItem(value: 'EN_COURS', label: 'En cours'),
  FilterItem(value: 'TERMINÉ', label: 'Terminé'),
  FilterItem(value: 'ANNULÉ', label: 'Annulé'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class TripsGarePage extends ConsumerStatefulWidget {
  const TripsGarePage({super.key});

  @override
  ConsumerState<TripsGarePage> createState() => _TripsGarePageState();
}

class _TripsGarePageState extends ConsumerState<TripsGarePage> {
  String _filter = 'TOUS';
  String _search = '';
  final Set<int> _archivedIds = {};
  bool _showArchived = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(_myTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mes trajets',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_archivedIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _showArchived = !_showArchived),
              child: Text(
                _showArchived ? 'Masquer archivés' : 'Voir archivés',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_myTripsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/gare/trips/create');
          if (result == true) ref.invalidate(_myTripsProvider);
        },
        backgroundColor: AppColors.mobiliBlue,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(
          'Nouveau trajet',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          SearchFilterBar(
            hintText: 'Rechercher un trajet...',
            filterValue: _filter,
            filterItems: _tripFilterItems,
            controller: _searchCtrl,
            onSearchChanged: (v) => setState(() => _search = v),
            onFilterChanged: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: tripsAsync.when(
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
                      'Erreur : $e',
                      style: const TextStyle(color: AppColors.gray500),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_myTripsProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (trips) {
                var filtered = trips.where((t) {
                  if (_archivedIds.contains(t.id)) return _showArchived;
                  if (_filter != 'TOUS' && t.status != _filter) return false;
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    return t.departureCity.toLowerCase().contains(q) ||
                        t.arrivalCity.toLowerCase().contains(q) ||
                        t.vehiculePlateNumber.toLowerCase().contains(q);
                  }
                  return true;
                }).toList();

                filtered.sort(
                  (a, b) => b.departureDateTime.compareTo(a.departureDateTime),
                );

                if (filtered.isEmpty) {
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
                            Icons.directions_bus_rounded,
                            color: AppColors.mobiliBlue,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Aucun trajet trouvé',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.mobiliBlueDeep,
                            fontSize: 16,
                          ),
                        ),
                        if (_archivedIds.isNotEmpty && !_showArchived) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_archivedIds.length} trajet(s) masqué(s)',
                            style: const TextStyle(
                              color: AppColors.gray400,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showArchived = true),
                            child: const Text('Afficher les masqués'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async => ref.invalidate(_myTripsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final trip = filtered[index];
                      final isArchived = _archivedIds.contains(trip.id);
                      return _TripCard(
                        trip: trip,
                        isArchived: isArchived,
                        onArchive: () => setState(() {
                          if (isArchived) {
                            _archivedIds.remove(trip.id);
                          } else {
                            _archivedIds.add(trip.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Trajet masqué'),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'Annuler',
                                  onPressed: () => setState(
                                    () => _archivedIds.remove(trip.id),
                                  ),
                                ),
                              ),
                            );
                          }
                        }),
                        onShowPassengers: () => _showPassengers(context, trip),
                        onOfflineSale: () => _showOfflineSale(context, trip),
                        onCanalTap: () => context.push(
                          '/gare/trips/canal/${trip.id}?label=${Uri.encodeComponent('${trip.departureCity} → ${trip.arrivalCity}')}',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

void _showPassengers(BuildContext context, TripItem trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PassengersSheet(trip: trip),
    );
  }

 void _showOfflineSale(BuildContext context, TripItem trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => OfflineSaleSheet(
        trip: trip,
        onSuccess: () {
          ref.invalidate(_myTripsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vente directe enregistrée ! ✅'),
              backgroundColor: AppColors.stationGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte trajet
// ─────────────────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onArchive,
    required this.isArchived,
    required this.onShowPassengers,
    required this.onOfflineSale,
    required this.onCanalTap,
  });
  final TripItem trip;
  final VoidCallback onArchive;
  final bool isArchived;
  final VoidCallback onShowPassengers;
  final VoidCallback onOfflineSale;
  final VoidCallback onCanalTap;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(trip.status);

    return Opacity(
      opacity: isArchived ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isArchived
                      ? [AppColors.gray400, AppColors.gray500]
                      : [const Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trip.departureCity,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
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
                            Flexible(
                              child: Text(
                                trip.arrivalCity,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: AppColors.mobiliYellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy à HH:mm',
                              ).format(trip.departureDateTime),
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusConfig.$1,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          trip.status,
                          style: TextStyle(
                            color: statusConfig.$2,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isArchived) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Masqué',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Infos
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.directions_bus_rounded,
                          label: trip.vehicleType.replaceAll('_', ' '),
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.confirmation_number_rounded,
                          label: trip.vehiculePlateNumber,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.event_seat_rounded,
                          label:
                              '${trip.availableSeats}/${trip.totalSeats} places',
                          color: trip.availableSeats <= 5
                              ? AppColors.danger
                              : AppColors.stationGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.payments_rounded,
                          label:
                              NumberFormat('#,###').format(trip.price) +
                              ' FCFA',
                          color: AppColors.proGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Taux remplissage (basé sur availableSeats = sièges confirmés)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Taux de remplissage',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gray400,
                            ),
                          ),
                          Text(
                            '${trip.occupancyRate}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: trip.occupancyRate >= 80
                                  ? AppColors.stationGreen
                                  : trip.occupancyRate >= 50
                                  ? AppColors.warning
                                  : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: trip.occupancyRate / 100,
                          backgroundColor: AppColors.gray100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            trip.occupancyRate >= 80
                                ? AppColors.stationGreen
                                : trip.occupancyRate >= 50
                                ? AppColors.warning
                                : AppColors.danger,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        trip.hasChauffeur
                            ? Icons.person_rounded
                            : Icons.person_off_rounded,
                        size: 14,
                        color: trip.hasChauffeur
                            ? AppColors.stationGreen
                            : AppColors.gray400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trip.chauffeurName,
                          style: TextStyle(
                            fontSize: 12,
                            color: trip.hasChauffeur
                                ? AppColors.stationGreen
                                : AppColors.gray400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (trip.stationName != null) ...[
                        const Icon(
                          Icons.store_rounded,
                          size: 13,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trip.stationName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            const Divider(height: 1, color: AppColors.gray100),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  // Ligne 1 : Passagers | Canal | Vente directe
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.people_rounded,
                          label: 'Passagers',
                          color: AppColors.mobiliBlue,
                          onTap: onShowPassengers,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Canal',
                          color: AppColors.stationGreen,
                          onTap: onCanalTap,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.point_of_sale_rounded,
                          label: 'Vente',
                          color: AppColors.proGold,
                          onTap: onOfflineSale,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Ligne 2 : Modifier | Masquer
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: const Text(
                            'Modifier',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gray600,
                            side: const BorderSide(color: AppColors.gray300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: onArchive,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isArchived
                              ? AppColors.stationGreen
                              : AppColors.gray400,
                          side: BorderSide(
                            color: isArchived
                                ? AppColors.stationGreen
                                : AppColors.gray300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 10,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: Icon(
                          isArchived
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'PROGRAMMÉ':
        return (AppColors.mobiliBlueFog, AppColors.mobiliBlue);
      case 'EN_COURS':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'TERMINÉ':
        return (AppColors.gray100, AppColors.gray500);
      case 'ANNULÉ':
        return (AppColors.dangerSoft, AppColors.danger);
      default:
        return (AppColors.warningSoft, AppColors.warning);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet passagers
// ─────────────────────────────────────────────────────────────────────────────

class _PassengersSheet extends ConsumerWidget {
  const _PassengersSheet({required this.trip});
  final TripItem trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengersAsync = ref.watch(_passengersProvider(trip.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Passagers confirmés',
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
              data: (passengers) {
                if (passengers.isEmpty) {
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

                final totalPassengers = passengers.fold(
                  0,
                  (sum, p) => sum + p.numberOfSeats,
                );
                final totalRevenue = passengers.fold(
                  0.0,
                  (sum, p) => sum + p.amount,
                );

                return Column(
                  children: [
                    // Stats
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mobiliBlueFog,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MiniStat(
                            label: 'Réservations',
                            value: '${passengers.length}',
                            color: AppColors.mobiliBlue,
                          ),
                          _MiniStat(
                            label: 'Passagers',
                            value: '$totalPassengers',
                            color: AppColors.stationGreen,
                          ),
                          _MiniStat(
                            label: 'Revenus',
                            value:
                                NumberFormat('#,###').format(totalRevenue) +
                                ' F',
                            color: AppColors.proGold,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: passengers.length,
                        itemBuilder: (ctx, i) =>
                            _PassengerCard(passenger: passengers[i]),
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

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.passenger});
  final PassengerItem passenger;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
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
          decoration: const BoxDecoration(
            color: AppColors.mobiliBlueFog,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              passenger.customerName.isNotEmpty
                  ? passenger.customerName[0].toUpperCase()
                  : '?',
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
                passenger.customerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.mobiliBlueDeep,
                ),
              ),
              Text(
                passenger.reference,
                style: const TextStyle(fontSize: 11, color: AppColors.gray400),
              ),
              if (passenger.boardingCity.isNotEmpty)
                Text(
                  '${passenger.boardingCity} → ${passenger.alightingCity}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mobiliBlue,
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${passenger.numberOfSeats} place(s)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.mobiliBlueDeep,
              ),
            ),
            Text(
              'Sièges: ${passenger.seatNumbers.join(', ')}',
              style: const TextStyle(fontSize: 11, color: AppColors.gray500),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: passenger.status == 'OFFLINE_SALE'
                    ? AppColors.mobiliBlueFog
                    : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                passenger.status == 'OFFLINE_SALE' ? 'Au guichet' : 'Via Mobili',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: passenger.status == 'OFFLINE_SALE'
                      ? AppColors.mobiliBlue
                      : AppColors.stationGreen,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet vente directe
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineSaleSheet extends StatefulWidget {
  const _OfflineSaleSheet({required this.trip, required this.onSuccess});
  final TripItem trip;
  final VoidCallback onSuccess;

  @override
  State<_OfflineSaleSheet> createState() => _OfflineSaleSheetState();
}

class _OfflineSaleSheetState extends State<_OfflineSaleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _passengerNameCtrl = TextEditingController();
  int _seats = 1;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _passengerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient.instance.dio;
      await dio.post<void>(
        '/bookings/partner/offline-sale',
        data: {
          'tripId': widget.trip.id,
          'numberOfSeats': _seats,
          'passengerNames': [_passengerNameCtrl.text.trim()],
          'seatSelections': [],
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('—')
            ? e.toString().split('—').last.trim()
            : 'Erreur lors de la vente';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vente directe',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mobiliBlueDeep,
                      ),
                    ),
                    Text(
                      '${widget.trip.departureCity} → ${widget.trip.arrivalCity}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.gray400),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Info trajet + prix
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mobiliBlueFog,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prix par place',
                      style: TextStyle(fontSize: 11, color: AppColors.gray500),
                    ),
                    Text(
                      NumberFormat('#,###').format(widget.trip.price) + ' FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.mobiliBlue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Places disponibles',
                      style: TextStyle(fontSize: 11, color: AppColors.gray500),
                    ),
                    Text(
                      '${widget.trip.availableSeats}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.stationGreen,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nom passager
          TextFormField(
            controller: _passengerNameCtrl,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            decoration: InputDecoration(
              labelText: 'Nom du passager',
              prefixIcon: const Icon(
                Icons.person_rounded,
                color: AppColors.gray400,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.gray50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.mobiliBlue,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nombre de places
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_seat_rounded,
                  color: AppColors.gray400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Nombre de places',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.mobiliBlueDeep,
                    ),
                  ),
                ),
                // Compteur
                Row(
                  children: [
                    GestureDetector(
                      onTap: _seats > 1 ? () => setState(() => _seats--) : null,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _seats > 1
                              ? AppColors.mobiliBlueFog
                              : AppColors.gray100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 18,
                          color: _seats > 1
                              ? AppColors.mobiliBlue
                              : AppColors.gray300,
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        '$_seats',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.mobiliBlueDeep,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _seats < widget.trip.availableSeats
                          ? () => setState(() => _seats++)
                          : null,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _seats < widget.trip.availableSeats
                              ? AppColors.mobiliBlueFog
                              : AppColors.gray100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: _seats < widget.trip.availableSeats
                              ? AppColors.mobiliBlue
                              : AppColors.gray300,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Total
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.proGoldSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.proGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total à percevoir',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.proGold,
                  ),
                ),
                Text(
                  NumberFormat('#,###').format(widget.trip.price * _seats) +
                      ' FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.proGold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mobiliBlue,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Enregistrer $_seats place(s) — ${NumberFormat('#,###').format(widget.trip.price * _seats)} FCFA',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helper
// ─────────────────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
