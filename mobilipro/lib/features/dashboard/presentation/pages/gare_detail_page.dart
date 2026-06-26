import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────────────────────

class GareChauffeur {
  const GareChauffeur({
    required this.id,
    required this.firstname,
    required this.lastname,
  });
  final int id;
  final String firstname;
  final String lastname;
  String get fullName => '$firstname $lastname';
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';

  factory GareChauffeur.fromJson(Map<String, dynamic> json) => GareChauffeur(
    id: json['id'] as int,
    firstname: json['firstname'] as String? ?? '',
    lastname: json['lastname'] as String? ?? '',
  );
}

class GareStats {
  const GareStats({
    required this.activeTripsCount,
    required this.totalBookingsCount,
    required this.totalRevenue,
    required this.revenueOnline,
    required this.revenueOffline,
  });
  final int activeTripsCount;
  final int totalBookingsCount;
  final double totalRevenue;
  final double revenueOnline;
  final double revenueOffline;

  factory GareStats.fromJson(Map<String, dynamic> json) => GareStats(
    activeTripsCount: (json['activeTripsCount'] as num?)?.toInt() ?? 0,
    totalBookingsCount: (json['totalBookingsCount'] as num?)?.toInt() ?? 0,
    totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
    revenueOnline: (json['revenueOnline'] as num?)?.toDouble() ?? 0.0,
    revenueOffline: (json['revenueOffline'] as num?)?.toDouble() ?? 0.0,
  );
}

class GareTrip {
  const GareTrip({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDateTime,
    required this.status,
    required this.vehicleType,
    required this.totalSeats,
    required this.availableSeats,
    required this.price,
    required this.stationId,
  });
  final int id;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDateTime;
  final String status;
  final String vehicleType;
  final int totalSeats;
  final int availableSeats;
  final double price;
  final int? stationId;

  String get formattedDate =>
      DateFormat('dd/MM/yyyy à HH:mm').format(departureDateTime);

  String get vehicleLabel {
    switch (vehicleType.toUpperCase()) {
      case 'BUS_CLIMATISE':
        return 'Bus Climatisé';
      case 'BUS_CLASSIQUE':
        return 'Bus Classique';
      case 'MINIBUS':
        return 'Minibus';
      case 'MASSA_NORMAL':
        return 'Massa';
      default:
        return vehicleType.replaceAll('_', ' ');
    }
  }

  factory GareTrip.fromJson(Map<String, dynamic> json) => GareTrip(
    id: json['id'] as int,
    departureCity: json['departureCity'] as String? ?? '',
    arrivalCity: json['arrivalCity'] as String? ?? '',
    departureDateTime:
        DateTime.tryParse(json['departureDateTime'] as String? ?? '') ??
        DateTime.now(),
    status: json['status'] as String? ?? '',
    vehicleType: json['vehicleType'] as String? ?? '',
    totalSeats: (json['totalSeats'] as num?)?.toInt() ?? 0,
    availableSeats: (json['availableSeats'] as num?)?.toInt() ?? 0,
    price: (json['price'] as num?)?.toDouble() ?? 0,
    stationId: json['stationId'] as int?,
  );
}

class GareBookingItem {
  const GareBookingItem({
    required this.id,
    required this.tripId,
    required this.passengerNames,
    required this.seatNumbers,
    required this.amount,
    required this.status,
    required this.boardingCity,
    required this.alightingCity,
  });
  final int id;
  final int tripId;
  final List<String> passengerNames;
  final List<String> seatNumbers;
  final double amount;
  final String status;
  final String boardingCity;
  final String alightingCity;

  String get displayName =>
      passengerNames.isNotEmpty ? passengerNames.join(', ') : '—';

  factory GareBookingItem.fromJson(Map<String, dynamic> json) =>
      GareBookingItem(
        id: json['id'] as int,
        tripId: (json['tripId'] as int?) ?? 0,
        passengerNames: (json['passengerNames'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        seatNumbers: (json['seatNumbers'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? '',
        boardingCity: json['boardingCity'] as String? ?? '',
        alightingCity: json['alightingCity'] as String? ?? '',
      );
}

class TripWithBookings {
  const TripWithBookings({required this.trip, required this.bookings});
  final GareTrip trip;
  final List<GareBookingItem> bookings;

  double get revenue => bookings
      .where((b) => b.status == 'CONFIRMED' || b.status == 'OFFLINE_SALE')
      .fold(0.0, (s, b) => s + b.amount);

  double get revenueOnline => bookings
      .where((b) => b.status == 'CONFIRMED')
      .fold(0.0, (s, b) => s + b.amount);

  double get revenueOffline => bookings
      .where((b) => b.status == 'OFFLINE_SALE')
      .fold(0.0, (s, b) => s + b.amount);

  int get passengersCount => bookings
      .where((b) => b.status == 'CONFIRMED' || b.status == 'OFFLINE_SALE')
      .fold(0, (s, b) => s + b.passengerNames.length);
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _gareStatsProvider = FutureProvider.autoDispose.family<GareStats, int>((
  ref,
  stationId,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<Map<String, dynamic>>(
    '/partenaire/dashboard/stats',
    queryParameters: {'stationId': stationId},
  );
  return GareStats.fromJson(response.data!);
});

final _gareTripsAndBookingsProvider = FutureProvider.autoDispose
    .family<List<TripWithBookings>, int>((ref, stationId) async {
      final dio = ApiClient.instance.dio;

      final results = await Future.wait([
        dio.get<List<dynamic>>('/trips/my-trips'),
        dio.get<List<dynamic>>('/bookings/partner/my-bookings'),
      ]);

      final allTrips = (results[0].data ?? [])
          .map((e) => GareTrip.fromJson(e as Map<String, dynamic>))
          .where((t) => t.stationId == stationId)
          .toList();

      final allBookings = (results[1].data ?? [])
          .map((e) => GareBookingItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final Map<int, List<GareBookingItem>> byTrip = {};
      for (final b in allBookings) {
        byTrip.putIfAbsent(b.tripId, () => []).add(b);
      }

      final result = allTrips
          .map((t) => TripWithBookings(trip: t, bookings: byTrip[t.id] ?? []))
          .toList();

      result.sort(
        (a, b) => b.trip.departureDateTime.compareTo(a.trip.departureDateTime),
      );

      return result;
    });

// ─────────────────────────────────────────────────────────────────────────────
// Filtre enum
// ─────────────────────────────────────────────────────────────────────────────

enum TripFilter { tous, programmes, enCours, passes }

extension TripFilterLabel on TripFilter {
  String get label {
    switch (this) {
      case TripFilter.tous:
        return 'Tous';
      case TripFilter.programmes:
        return 'Programmés';
      case TripFilter.enCours:
        return 'En cours';
      case TripFilter.passes:
        return 'Passés';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class GareDetailPage extends ConsumerStatefulWidget {
  const GareDetailPage({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.city,
    required this.active,
    required this.responsibleName,
    required this.chauffeurs,
  });

  final int stationId;
  final String stationName;
  final String city;
  final bool active;
  final String responsibleName;
  final List<GareChauffeur> chauffeurs;

  @override
  ConsumerState<GareDetailPage> createState() => _GareDetailPageState();
}

class _GareDetailPageState extends ConsumerState<GareDetailPage> {
  TripFilter _filter = TripFilter.tous;

  List<TripWithBookings> _applyFilter(List<TripWithBookings> items) {
    final now = DateTime.now();
    switch (_filter) {
      case TripFilter.tous:
        return items;
      case TripFilter.programmes:
        return items
            .where(
              (t) =>
                  t.trip.status.contains('PROGRAMM') &&
                  t.trip.departureDateTime.isAfter(now),
            )
            .toList();
      case TripFilter.enCours:
        return items
            .where(
              (t) =>
                  t.trip.status.contains('EN_COURS') ||
                  t.trip.status.contains('EN COURS'),
            )
            .toList();
      case TripFilter.passes:
        return items
            .where(
              (t) =>
                  t.trip.status.contains('TERMIN') ||
                  t.trip.departureDateTime.isBefore(now),
            )
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(_gareStatsProvider(widget.stationId));
    final tripsAsync = ref.watch(
      _gareTripsAndBookingsProvider(widget.stationId),
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async {
          ref.invalidate(_gareStatsProvider(widget.stationId));
          ref.invalidate(_gareTripsAndBookingsProvider(widget.stationId));
        },
        child: CustomScrollView(
          slivers: [
            // AppBar
            SliverAppBar(
              expandedHeight: 170,
              pinned: true,
              backgroundColor: AppColors.mobiliBlue,
              foregroundColor: AppColors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: widget.active
                                  ? AppColors.stationGreen
                                  : AppColors.gray400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.store_rounded,
                              color: AppColors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.stationName,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  widget.city,
                                  style: TextStyle(
                                    color: AppColors.white.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.active
                                  ? AppColors.stationGreen.withValues(
                                      alpha: 0.2,
                                    )
                                  : AppColors.danger.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.active
                                    ? AppColors.stationGreen.withValues(
                                        alpha: 0.5,
                                      )
                                    : AppColors.danger.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              widget.active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: widget.active
                                    ? AppColors.stationGreen
                                    : AppColors.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            color: AppColors.mobiliYellow,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Responsable : ${widget.responsibleName}',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.directions_car_rounded,
                            color: AppColors.mobiliYellow,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.chauffeurs.length} chauffeur(s)',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats
                    statsAsync.when(
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mobiliBlue,
                          ),
                        ),
                      ),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (stats) => Column(
                        children: [
                          Row(
                            children: [
                              _StatMini(
                                label: 'Trajets',
                                value: '${stats.activeTripsCount}',
                                color: AppColors.mobiliBlue,
                              ),
                              const SizedBox(width: 10),
                              _StatMini(
                                label: 'Réservations',
                                value: '${stats.totalBookingsCount}',
                                color: AppColors.stationGreen,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0A1F6E),
                                  AppColors.mobiliBlueDeep,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.payments_rounded,
                                      color: AppColors.mobiliYellow,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Revenus totaux',
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      NumberFormat(
                                            '#,###',
                                          ).format(stats.totalRevenue) +
                                          ' FCFA',
                                      style: const TextStyle(
                                        color: AppColors.mobiliYellow,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _RevenueChip(
                                        icon: Icons.wifi_rounded,
                                        label: 'En ligne',
                                        amount: stats.revenueOnline,
                                        color: AppColors.stationGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _RevenueChip(
                                        icon: Icons.point_of_sale_rounded,
                                        label: 'Physique',
                                        amount: stats.revenueOffline,
                                        color: AppColors.mobiliYellow,
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

                    const SizedBox(height: 20),

                    // Filtres
                    const Text(
                      'Trajets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mobiliBlueDeep,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: TripFilter.values
                            .map(
                              (f) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setState(() => _filter = f),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _filter == f
                                          ? AppColors.mobiliBlue
                                          : AppColors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _filter == f
                                            ? AppColors.mobiliBlue
                                            : AppColors.gray200,
                                      ),
                                    ),
                                    child: Text(
                                      f.label,
                                      style: TextStyle(
                                        color: _filter == f
                                            ? AppColors.white
                                            : AppColors.gray600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Trajets avec réservations
                    tripsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                      error: (e, _) => Text(
                        'Erreur : $e',
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      data: (items) {
                        final filtered = _applyFilter(items);
                        if (filtered.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.directions_bus_outlined,
                                    color: AppColors.gray300,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Aucun trajet ${_filter.label.toLowerCase()}',
                                    style: const TextStyle(
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: filtered
                              .map((t) => _TripAccordion(item: t))
                              .toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Chauffeurs
                    if (widget.chauffeurs.isNotEmpty) ...[
                      const Text(
                        'Chauffeurs affectés',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mobiliBlueDeep,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.chauffeurs
                          .map((c) => _ChauffeurRow(chauffeur: c))
                          .toList(),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accordion trajet
// ─────────────────────────────────────────────────────────────────────────────

class _TripAccordion extends StatelessWidget {
  const _TripAccordion({required this.item});
  final TripWithBookings item;

  @override
  Widget build(BuildContext context) {
    final trip = item.trip;
    final bookings = item.bookings;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Route
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trip.departureCity,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.mobiliYellow,
                                size: 13,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                trip.arrivalCity,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
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
                        Text(
                          trip.vehicleLabel,
                          style: TextStyle(
                            color: AppColors.mobiliYellow.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stats trajet
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Revenus
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.proGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.proGold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          NumberFormat('#,###').format(item.revenue) + ' F',
                          style: const TextStyle(
                            color: AppColors.mobiliYellow,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // En ligne + physique
                      if (item.revenueOnline > 0 || item.revenueOffline > 0)
                        Row(
                          children: [
                            if (item.revenueOnline > 0) ...[
                              const Icon(
                                Icons.wifi_rounded,
                                size: 9,
                                color: AppColors.stationGreen,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                NumberFormat(
                                      '#,###',
                                    ).format(item.revenueOnline) +
                                    ' F',
                                style: const TextStyle(
                                  color: AppColors.stationGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            if (item.revenueOffline > 0) ...[
                              const Icon(
                                Icons.point_of_sale_rounded,
                                size: 9,
                                color: AppColors.mobiliYellow,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                NumberFormat(
                                      '#,###',
                                    ).format(item.revenueOffline) +
                                    ' F',
                                style: const TextStyle(
                                  color: AppColors.mobiliYellow,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 3),
                      // Passagers + places
                      Row(
                        children: [
                          const Icon(
                            Icons.people_rounded,
                            size: 11,
                            color: AppColors.mobiliYellow,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.passengersCount}/${trip.totalSeats}',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      // Statut
                      _StatusBadge(status: trip.status),
                    ],
                  ),
                ],
              ),
            ),
            children: bookings.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Aucune réservation',
                        style: TextStyle(
                          color: AppColors.gray400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ]
                : bookings.map((b) => _BookingRow(booking: b)).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne réservation dans accordion
// ─────────────────────────────────────────────────────────────────────────────

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});
  final GareBookingItem booking;

  @override
  Widget build(BuildContext context) {
    // Si plusieurs passagers → une ligne par passager
    if (booking.passengerNames.length > 1) {
      return Column(
        children: List.generate(booking.passengerNames.length, (i) {
          final name = booking.passengerNames[i];
          final seat = i < booking.seatNumbers.length
              ? booking.seatNumbers[i]
              : '—';
          return _PassengerLine(
            name: name,
            seat: seat,
            status: booking.status,
            troncon: booking.boardingCity.isNotEmpty
                ? '${booking.boardingCity} → ${booking.alightingCity}'
                : null,
          );
        }),
      );
    }

    return _PassengerLine(
      name: booking.passengerNames.isNotEmpty
          ? booking.passengerNames.first
          : '—',
      seat: booking.seatNumbers.isNotEmpty ? booking.seatNumbers.first : '—',
      status: booking.status,
      troncon: booking.boardingCity.isNotEmpty
          ? '${booking.boardingCity} → ${booking.alightingCity}'
          : null,
    );
  }
}

class _PassengerLine extends StatelessWidget {
  const _PassengerLine({
    required this.name,
    required this.seat,
    required this.status,
    this.troncon,
  });
  final String name;
  final String seat;
  final String status;
  final String? troncon;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(status);

    return Column(
      children: [
        const Divider(height: 1, color: AppColors.gray100),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.mobiliBlueFog,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.mobiliBlue,
                      fontSize: 14,
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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.mobiliBlueDeep,
                      ),
                    ),
                    if (troncon != null)
                      Text(
                        troncon!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Siège
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.mobiliBlueDeep,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Siège $seat',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Statut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: statusConfig.$1,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusConfig.$2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'CONFIRMED':
        return 'Confirmé';
      case 'PENDING':
        return 'Attente';
      case 'CANCELLED':
        return 'Annulé';
      case 'OFFLINE_SALE':
        return 'Physique';
      default:
        return s;
    }
  }

  (Color, Color) _statusConfig(String s) {
    switch (s.toUpperCase()) {
      case 'CONFIRMED':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'PENDING':
        return (AppColors.warningSoft, AppColors.warning);
      case 'CANCELLED':
        return (AppColors.dangerSoft, AppColors.danger);
      case 'OFFLINE_SALE':
        return (AppColors.mobiliBlueFog, AppColors.mobiliBlue);
      default:
        return (AppColors.gray100, AppColors.gray500);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge statut trajet
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    if (status.contains('PROGRAMM')) {
      bg = AppColors.mobiliBlueFog;
      fg = AppColors.mobiliBlue;
      label = 'Programmé';
    } else if (status.contains('EN_COURS') || status.contains('EN COURS')) {
      bg = const Color(0xFFD1FAE5);
      fg = AppColors.stationGreen;
      label = 'En cours';
    } else if (status.contains('TERMIN')) {
      bg = AppColors.gray100;
      fg = AppColors.gray500;
      label = 'Terminé';
    } else if (status.contains('ANNUL')) {
      bg = AppColors.dangerSoft;
      fg = AppColors.danger;
      label = 'Annulé';
    } else {
      bg = AppColors.gray100;
      fg = AppColors.gray500;
      label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helper
// ─────────────────────────────────────────────────────────────────────────────

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 22,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RevenueChip extends StatelessWidget {
  const _RevenueChip({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });
  final IconData icon;
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: color)),
              Text(
                NumberFormat('#,###').format(amount) + ' F',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ChauffeurRow extends StatelessWidget {
  const _ChauffeurRow({required this.chauffeur});
  final GareChauffeur chauffeur;

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
              chauffeur.initial,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.mobiliBlue,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            chauffeur.fullName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.mobiliBlueDeep,
            ),
          ),
        ),
        const Icon(
          Icons.directions_car_rounded,
          color: AppColors.gray300,
          size: 18,
        ),
      ],
    ),
  );
}
