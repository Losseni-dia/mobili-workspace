import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/search_filter_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────────────────────

class BookingItem {
  const BookingItem({
    required this.id,
    required this.tripId,
    required this.reference,
    required this.customerName,
    required this.departureCity,
    required this.arrivalCity,
    required this.boardingCity,
    required this.alightingCity,
    required this.departureDateTime,
    required this.bookingDate,
    required this.amount,
    required this.numberOfSeats,
    required this.status,
    required this.passengerNames,
    required this.seatNumbers,
  });

  final int id;
  final int tripId;
  final String reference;
  final String customerName;
  final String departureCity;
  final String arrivalCity;
  final String boardingCity;
  final String alightingCity;
  final DateTime departureDateTime;
  final DateTime bookingDate;
  final double amount;
  final int numberOfSeats;
  final String status;
  final List<String> passengerNames;
  final List<String> seatNumbers;

  String get displayName =>
      passengerNames.isNotEmpty ? passengerNames.join(', ') : customerName;

  factory BookingItem.fromJson(Map<String, dynamic> json) => BookingItem(
    id: json['id'] as int,
    tripId: (json['tripId'] as int?) ?? 0,
    reference: json['reference'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    departureCity: json['departureCity'] as String? ?? '',
    arrivalCity: json['arrivalCity'] as String? ?? '',
    boardingCity: json['boardingCity'] as String? ?? '',
    alightingCity: json['alightingCity'] as String? ?? '',
    departureDateTime:
        DateTime.tryParse(json['departureDateTime'] as String? ?? '') ??
        DateTime.now(),
    bookingDate:
        DateTime.tryParse(json['bookingDate'] as String? ?? '') ??
        DateTime.now(),
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    numberOfSeats: (json['numberOfSeats'] as num?)?.toInt() ?? 1,
    status: json['status'] as String? ?? '',
    passengerNames: (json['passengerNames'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    seatNumbers: (json['seatNumbers'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
  );
}

class TripGroup {
  const TripGroup({
    required this.tripId,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDateTime,
    required this.vehicleType,
    required this.status,
    required this.bookings,
  });

  final int tripId;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDateTime;
  final String vehicleType;
  final String status;
  final List<BookingItem> bookings;

  double get totalRevenue => bookings
      .where((b) => b.status == 'CONFIRMED' || b.status == 'OFFLINE_SALE')
      .fold(0.0, (s, b) => s + b.amount);

  double get revenueOnline => bookings
      .where((b) => b.status == 'CONFIRMED')
      .fold(0.0, (s, b) => s + b.amount);

  double get revenueOffline => bookings
      .where((b) => b.status == 'OFFLINE_SALE')
      .fold(0.0, (s, b) => s + b.amount);

  int get totalPassengers => bookings
      .where((b) => b.status == 'CONFIRMED' || b.status == 'OFFLINE_SALE')
      .fold(0, (s, b) => s + b.numberOfSeats);
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final _bookingsGroupedProvider = FutureProvider.autoDispose<List<TripGroup>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final results = await Future.wait([
    dio.get<List<dynamic>>('/trips/my-trips'),
    dio.get<List<dynamic>>('/bookings/partner/my-bookings'),
  ]);

  final trips = results[0].data ?? [];
  final bookings = (results[1].data ?? [])
      .map((e) => BookingItem.fromJson(e as Map<String, dynamic>))
      .toList();

  final Map<int, List<BookingItem>> byTrip = {};
  for (final b in bookings) {
    byTrip.putIfAbsent(b.tripId, () => []).add(b);
  }

  final groups = <TripGroup>[];
  for (final t in trips) {
    final tripId = t['id'] as int;
    final tripBookings = byTrip[tripId] ?? [];
    if (tripBookings.isEmpty) continue;
    groups.add(
      TripGroup(
        tripId: tripId,
        departureCity: t['departureCity'] as String? ?? '',
        arrivalCity: t['arrivalCity'] as String? ?? '',
        departureDateTime:
            DateTime.tryParse(t['departureDateTime'] as String? ?? '') ??
            DateTime.now(),
        vehicleType: t['vehicleType'] as String? ?? '',
        status: t['status'] as String? ?? '',
        bookings: tripBookings,
      ),
    );
  }

  groups.sort((a, b) => b.departureDateTime.compareTo(a.departureDateTime));
  return groups;
});

// ─────────────────────────────────────────────────────────────────────────────
// Constantes
// ─────────────────────────────────────────────────────────────────────────────

const _bookingFilterItems = [
  FilterItem(value: 'TOUS', label: 'Tous'),
  FilterItem(value: 'CONFIRMED', label: 'Via Mobili'),
  FilterItem(value: 'PENDING', label: 'En attente'),
  FilterItem(value: 'CANCELLED', label: 'Annulé'),
  FilterItem(value: 'OFFLINE_SALE', label: 'Au guichet'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class BookingsGarePage extends ConsumerStatefulWidget {
  const BookingsGarePage({super.key});

  @override
  ConsumerState<BookingsGarePage> createState() => _BookingsGarePageState();
}

class _BookingsGarePageState extends ConsumerState<BookingsGarePage> {
  String _filter = 'TOUS';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(_bookingsGroupedProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Réservations',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_bookingsGroupedProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          SearchFilterBar(
            hintText: 'Rechercher passager, référence...',
            filterValue: _filter,
            filterItems: _bookingFilterItems,
            controller: _searchCtrl,
            onSearchChanged: (v) => setState(() => _search = v),
            onFilterChanged: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: groupsAsync.when(
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
                      onPressed: () => ref.invalidate(_bookingsGroupedProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (groups) {
                final totalRevenue = groups.fold(
                  0.0,
                  (s, g) => s + g.totalRevenue,
                );
                final revenueOnline = groups.fold(
                  0.0,
                  (s, g) => s + g.revenueOnline,
                );
                final revenueOffline = groups.fold(
                  0.0,
                  (s, g) => s + g.revenueOffline,
                );
                final totalPassengers = groups.fold(
                  0,
                  (s, g) => s + g.totalPassengers,
                );

                var filtered = groups.where((g) {
                  final fb = _filterBookings(g.bookings, _filter, _search);
                  return fb.isNotEmpty;
                }).toList();

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async =>
                      ref.invalidate(_bookingsGroupedProvider),
                  child: CustomScrollView(
                    slivers: [
                      // Stats
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Ligne 1 : Trajets + Passagers
                              Row(
                                children: [
                                  _StatMini(
                                    label: 'Trajets',
                                    value: '${groups.length}',
                                    color: AppColors.mobiliBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  _StatMini(
                                    label: 'Passagers',
                                    value: '$totalPassengers',
                                    color: AppColors.stationGreen,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Ligne 2 : Revenus en ligne + physique
                              Row(
                                children: [
                                  Expanded(
                                    child: _RevenueChip(
                                      icon: Icons.wifi_rounded,
                                      label: 'Via Mobili',
                                      amount: revenueOnline,
                                      color: AppColors.stationGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _RevenueChip(
                                      icon: Icons.point_of_sale_rounded,
                                      label: 'Au guichet',
                                      amount: revenueOffline,
                                      color: AppColors.proGold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _RevenueChip(
                                      icon: Icons.payments_rounded,
                                      label: 'Total',
                                      amount: totalRevenue,
                                      color: AppColors.mobiliBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          child: Center(
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
                                    Icons.bookmark_outline_rounded,
                                    color: AppColors.mobiliBlue,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Aucune réservation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.mobiliBlueDeep,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _TripAccordion(
                                group: filtered[i],
                                filter: _filter,
                                search: _search,
                              ),
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<BookingItem> _filterBookings(
    List<BookingItem> bookings,
    String filter,
    String search,
  ) {
    return bookings.where((b) {
      if (filter != 'TOUS' && b.status != filter) return false;
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        return b.reference.toLowerCase().contains(q) ||
            b.customerName.toLowerCase().contains(q) ||
            b.passengerNames.any((n) => n.toLowerCase().contains(q)) ||
            b.boardingCity.toLowerCase().contains(q) ||
            b.alightingCity.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accordion trajet
// ─────────────────────────────────────────────────────────────────────────────

class _TripAccordion extends StatelessWidget {
  const _TripAccordion({
    required this.group,
    required this.filter,
    required this.search,
  });
  final TripGroup group;
  final String filter;
  final String search;

  @override
  Widget build(BuildContext context) {
    final filteredBookings = group.bookings.where((b) {
      if (filter != 'TOUS' && b.status != filter) return false;
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        return b.reference.toLowerCase().contains(q) ||
            b.customerName.toLowerCase().contains(q) ||
            b.passengerNames.any((n) => n.toLowerCase().contains(q)) ||
            b.boardingCity.toLowerCase().contains(q) ||
            b.alightingCity.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final tripOnline = filteredBookings
        .where((b) => b.status == 'CONFIRMED')
        .fold(0.0, (s, b) => s + b.amount);
    final tripOffline = filteredBookings
        .where((b) => b.status == 'OFFLINE_SALE')
        .fold(0.0, (s, b) => s + b.amount);
    final tripTotal = tripOnline + tripOffline;

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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.departureCity,
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
                                group.arrivalCity,
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
                          DateFormat(
                            'dd/MM/yyyy à HH:mm',
                          ).format(group.departureDateTime),
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          group.vehicleType.replaceAll('_', ' '),
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
                  // Revenus en ligne + physique
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Total
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
                          NumberFormat('#,###').format(tripTotal) + ' F',
                          style: const TextStyle(
                            color: AppColors.mobiliYellow,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // En ligne + physique
                      Row(
                        children: [
                          if (tripOnline > 0) ...[
                            const Icon(
                              Icons.wifi_rounded,
                              size: 10,
                              color: AppColors.stationGreen,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              NumberFormat('#,###').format(tripOnline) + ' F',
                              style: const TextStyle(
                                color: AppColors.stationGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (tripOffline > 0) ...[
                            const Icon(
                              Icons.point_of_sale_rounded,
                              size: 10,
                              color: AppColors.mobiliYellow,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              NumberFormat('#,###').format(tripOffline) + ' F',
                              style: const TextStyle(
                                color: AppColors.mobiliYellow,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_rounded,
                            size: 11,
                            color: AppColors.mobiliYellow,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${filteredBookings.length} rés.',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            children: [
              ...filteredBookings.map(
                (b) => _PassengerRow(
                  booking: b,
                  isLast: b == filteredBookings.last,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne passager
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({required this.booking, required this.isLast});
  final BookingItem booking;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(booking.status);

    if (booking.passengerNames.length > 1) {
      return Column(
        children: List.generate(booking.passengerNames.length, (i) {
          final name = booking.passengerNames[i];
          final seat = i < booking.seatNumbers.length
              ? booking.seatNumbers[i]
              : '—';
          return _SinglePassengerLine(
            name: name,
            seat: seat,
            reference: booking.reference,
            statusColor: statusConfig.$2,
            statusBg: statusConfig.$1,
            statusLabel: _statusLabel(booking.status),
            troncon: booking.boardingCity.isNotEmpty
                ? '${booking.boardingCity} → ${booking.alightingCity}'
                : null,
          );
        }),
      );
    }

    return _SinglePassengerLine(
      name: booking.passengerNames.isNotEmpty
          ? booking.passengerNames.first
          : booking.customerName,
      seat: booking.seatNumbers.isNotEmpty ? booking.seatNumbers.first : '—',
      reference: booking.reference,
      statusColor: statusConfig.$2,
      statusBg: statusConfig.$1,
      statusLabel: _statusLabel(booking.status),
      troncon: booking.boardingCity.isNotEmpty
          ? '${booking.boardingCity} → ${booking.alightingCity}'
          : null,
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'CONFIRMED':
        return 'Via Mobili';
      case 'PENDING':
        return 'Attente';
      case 'CANCELLED':
        return 'Annulé';
      case 'OFFLINE_SALE':
        return 'Au guichet';
      default:
        return status;
    }
  }

  (Color, Color) _statusConfig(String status) {
    switch (status) {
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

class _SinglePassengerLine extends StatelessWidget {
  const _SinglePassengerLine({
    required this.name,
    required this.seat,
    required this.reference,
    required this.statusColor,
    required this.statusBg,
    required this.statusLabel,
    this.troncon,
  });

  final String name;
  final String seat;
  final String reference;
  final Color statusColor;
  final Color statusBg;
  final String statusLabel;
  final String? troncon;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(height: 1, color: AppColors.gray100),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
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
                    fontSize: 15,
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
                  Text(
                    reference,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helper
// ─────────────────────────────────────────────────────────────────────────────

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
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
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
              fontSize: 18,
            ),
          ),
        ],
      ),
    ),
  );
}
