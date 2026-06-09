import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/search_filter_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────

class BookingItem {
  const BookingItem({
    required this.id,
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
    this.moreInfo,
  });

  final int id;
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
  final String? moreInfo;

  String get formattedAmount => NumberFormat('#,###').format(amount) + ' FCFA';

  String get formattedDate =>
      DateFormat('dd/MM/yyyy HH:mm').format(departureDateTime);

  String get formattedBookingDate =>
      DateFormat('dd/MM/yyyy à HH:mm').format(bookingDate);

  factory BookingItem.fromJson(Map<String, dynamic> json) => BookingItem(
    id: json['id'] as int,
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
    moreInfo: json['moreInfo'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final _partnerBookingsProvider = FutureProvider.autoDispose<List<BookingItem>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<List<dynamic>>(
    '/bookings/partner/my-bookings',
  );
  return (response.data ?? [])
      .map((e) => BookingItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

const _bookingFilterItems = [
  FilterItem(value: 'TOUS', label: 'Tous'),
  FilterItem(value: 'CONFIRMED', label: 'Confirmé'),
  FilterItem(value: 'PENDING', label: 'En attente'),
  FilterItem(value: 'CANCELLED', label: 'Annulé'),
  FilterItem(value: 'OFFLINE_SALE', label: 'Vente directe'),
];

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
    final bookingsAsync = ref.watch(_partnerBookingsProvider);

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
            onPressed: () => ref.invalidate(_partnerBookingsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre recherche + filtre réutilisable
          SearchFilterBar(
            hintText: 'Rechercher par client, référence...',
            filterValue: _filter,
            filterItems: _bookingFilterItems,
            controller: _searchCtrl,
            onSearchChanged: (v) => setState(() => _search = v),
            onFilterChanged: (v) => setState(() => _filter = v),
          ),

          Expanded(
            child: bookingsAsync.when(
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
                      onPressed: () => ref.invalidate(_partnerBookingsProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (bookings) {
                final total = bookings.length;
                final confirmed = bookings
                    .where((b) => b.status == 'CONFIRMED')
                    .length;
                final revenue = bookings
                    .where(
                      (b) =>
                          b.status == 'CONFIRMED' || b.status == 'OFFLINE_SALE',
                    )
                    .fold(0.0, (sum, b) => sum + b.amount);

                var filtered = bookings.where((b) {
                  if (_filter != 'TOUS' && b.status != _filter) return false;
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    return b.customerName.toLowerCase().contains(q) ||
                        b.reference.toLowerCase().contains(q) ||
                        b.departureCity.toLowerCase().contains(q) ||
                        b.arrivalCity.toLowerCase().contains(q);
                  }
                  return true;
                }).toList();

                filtered.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async =>
                      ref.invalidate(_partnerBookingsProvider),
                  child: CustomScrollView(
                    slivers: [
                      // Stats
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _StatMini(
                                label: 'Total',
                                value: '$total',
                                color: AppColors.mobiliBlue,
                              ),
                              const SizedBox(width: 10),
                              _StatMini(
                                label: 'Confirmées',
                                value: '$confirmed',
                                color: AppColors.stationGreen,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.proGoldSoft,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.proGold.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Revenus',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.proGold,
                                        ),
                                      ),
                                      Text(
                                        NumberFormat('#,###').format(revenue) +
                                            ' F',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.proGold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                              (ctx, i) => _BookingCard(booking: filtered[i]),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte réservation
// ─────────────────────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(booking.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
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
                    booking.customerName.isNotEmpty
                        ? booking.customerName[0].toUpperCase()
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
                      booking.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.mobiliBlueDeep,
                      ),
                    ),
                    Text(
                      booking.reference,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    booking.formattedAmount,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mobiliBlueDeep,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusConfig.$1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(booking.status),
                      style: TextStyle(
                        color: statusConfig.$2,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            const Divider(height: 1, color: AppColors.gray100),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.route_rounded,
                  size: 14,
                  color: AppColors.mobiliBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${booking.boardingCity} → ${booking.alightingCity}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: AppColors.gray400,
                ),
                const SizedBox(width: 6),
                Text(
                  'Départ : ${booking.formattedDate}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.event_seat_rounded,
                  size: 13,
                  color: AppColors.gray400,
                ),
                const SizedBox(width: 6),
                Text(
                  'Sièges : ${booking.seatNumbers.join(', ')} — ${booking.numberOfSeats} passager(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: AppColors.gray400,
                ),
                const SizedBox(width: 6),
                Text(
                  'Réservé le ${booking.formattedBookingDate}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
            if (booking.passengerNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.gray100),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 13,
                    color: AppColors.mobiliBlue,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Passagers',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mobiliBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: booking.passengerNames
                    .map(
                      (name) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mobiliBlueFog,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: AppColors.mobiliBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mobiliBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'CONFIRMED':
        return 'Confirmé';
      case 'PENDING':
        return 'En attente';
      case 'CANCELLED':
        return 'Annulé';
      case 'OFFLINE_SALE':
        return 'Vente directe';
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

// ─────────────────────────────────────────────────────────────────────────────
// Widget stat mini
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
              fontSize: 20,
            ),
          ),
        ],
      ),
    ),
  );
}
