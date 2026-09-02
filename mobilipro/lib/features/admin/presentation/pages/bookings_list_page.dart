import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_filter_chip.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_period_selector.dart';

/// "Réservations" admin — parité web (admin-bookings.ts/html) : toutes compagnies confondues,
/// consomme le même endpoint que le web (/admin/stats/bookings/list, via bookingListProvider
/// déjà partagé avec les Stats métier). Numéros de sièges affichés (jamais juste un total), un
/// siège dont le ticket a été annulé individuellement reste visible mais barré/grisé — même
/// convention que côté partenaire/web (jamais retiré de la liste).
bool _isConfirmedBooking(AdminBookingListItem b) {
  final s = b.status.toUpperCase();
  return s == 'CONFIRMED' || s == 'OFFLINE_SALE';
}

bool _isCancelledBooking(AdminBookingListItem b) => b.status.toUpperCase() == 'CANCELLED';

class AdminBookingsListPage extends ConsumerStatefulWidget {
  const AdminBookingsListPage({super.key});
  @override
  ConsumerState<AdminBookingsListPage> createState() => _AdminBookingsListPageState();
}

class _AdminBookingsListPageState extends ConsumerState<AdminBookingsListPage> {
  AdminStatsPeriod _period = kPeriodMonth;
  String _search = '';
  String _statusFilter = 'CONFIRME';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminBookingListItem> _applyStatusFilter(List<AdminBookingListItem> bookings) =>
      _statusFilter == 'CONFIRME'
          ? bookings.where(_isConfirmedBooking).toList()
          : bookings.where(_isCancelledBooking).toList();

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(bookingListProvider((period: _period, search: _search)));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Réservations',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          AdminPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() {
              _period = p;
              _pageSize = 20;
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() {
                _search = v;
                _pageSize = 20;
              }),
              decoration: InputDecoration(
                hintText: 'Référence, client, compagnie…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.gray200),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                StatusFilterChip(
                  label: 'Confirmé',
                  selected: _statusFilter == 'CONFIRME',
                  onTap: () => setState(() {
                    _statusFilter = 'CONFIRME';
                    _pageSize = 20;
                  }),
                ),
                const SizedBox(width: 8),
                StatusFilterChip(
                  label: 'Annulé',
                  selected: _statusFilter == 'ANNULE',
                  onTap: () => setState(() {
                    _statusFilter = 'ANNULE';
                    _pageSize = 20;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(child: AdminErrorCard(message: 'Erreur : $e')),
              data: (allBookings) {
                final bookings = _applyStatusFilter(allBookings);
                // Montant confirmé — toujours calculé sur l'ensemble récupéré, jamais
                // influencé par le filtre de statut affiché (même convention que côté web).
                final confirmedAmount = allBookings
                    .where(_isConfirmedBooking)
                    .fold<double>(0, (s, b) => s + b.totalPrice);
                if (bookings.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune réservation trouvée',
                      style: TextStyle(color: AppColors.gray400),
                    ),
                  );
                }
                final visible = bookings.take(_pageSize).toList();
                final hasMore = bookings.length > _pageSize;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_rounded, color: AppColors.stationGreen, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${confirmedAmount.toStringAsFixed(0)} F',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.mobiliBlueDeep,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('confirmé', style: TextStyle(fontSize: 11, color: AppColors.gray500)),
                        ],
                      ),
                    ),
                    Text(
                      '${visible.length} / ${bookings.length} réservation(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...visible.map((b) => _AdminBookingCard(booking: b)),
                    if (hasMore)
                      LoadMoreButton(
                        remaining: bookings.length - _pageSize,
                        onTap: () => setState(() => _pageSize += 20),
                      ),
                    const SizedBox(height: 16),
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

class _AdminBookingCard extends StatelessWidget {
  const _AdminBookingCard({required this.booking});
  final AdminBookingListItem booking;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gray200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${booking.reference}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.mobiliBlueDeep,
                    ),
                  ),
                  Text(
                    '${booking.customerName} — ${booking.partnerName}',
                    style: const TextStyle(fontSize: 11, color: AppColors.gray500),
                  ),
                  Text(
                    booking.route,
                    style: const TextStyle(fontSize: 11, color: AppColors.gray500),
                  ),
                  Text(
                    'Résa ${DateFormat('dd/MM/yy HH:mm').format(booking.bookingDate)}'
                    '${booking.departureDateTime != null ? ' · Départ ${DateFormat('dd/MM/yy HH:mm').format(booking.departureDateTime!)}' : ''}',
                    style: const TextStyle(fontSize: 10, color: AppColors.gray400),
                  ),
                  if (!booking.isOfflineSale && booking.serviceFee != null)
                    Text(
                      'Forfait ${booking.serviceFee} F',
                      style: const TextStyle(fontSize: 10, color: AppColors.gray400),
                    ),
                ],
              ),
            ),
            Text(
              '${booking.totalPrice.toStringAsFixed(0)} F',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.proGold),
            ),
          ],
        ),
        if (booking.seatNumbers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: booking.seatNumbers
                .map(
                  (seat) => _SeatChip(
                    seat: seat,
                    cancelled: booking.isSeatCancelled(seat),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    ),
  );
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({required this.seat, required this.cancelled});
  final String seat;
  final bool cancelled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: cancelled ? AppColors.gray100 : AppColors.mobiliYellow,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      seat,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: cancelled ? AppColors.gray500 : AppColors.mobiliBlueDeep,
        decoration: cancelled ? TextDecoration.lineThrough : null,
      ),
    ),
  );
}
