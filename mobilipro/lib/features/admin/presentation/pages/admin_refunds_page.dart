import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mobilipro/core/network/api_client.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_period_selector.dart';

/// Réservations considérées "annulables" côté UI. BookingService.cancelBooking()
/// (backend) accepte n'importe quel statut différent de CANCELLED, mais on ne
/// propose ici que les deux statuts pour lesquels une annulation a un sens
/// métier réel : une réservation payée (CONFIRMED) ou en attente de paiement
/// (PENDING). Choix documenté dans le rapport de session.
const _cancellableStatuses = {'PENDING', 'CONFIRMED'};

/// Large fenêtre par défaut (1 an) : contrairement aux écrans de stats, cette
/// page ne sert pas à analyser une période précise mais à retrouver toute
/// réservation encore annulable, quelle que soit son ancienneté.
const AdminStatsPeriod _kWideDefault = (days: 365, fromDate: null, toDate: null);

class CancelBookingResult {
  const CancelBookingResult({
    required this.bookingId,
    required this.provider,
    required this.autoRefunded,
    required this.message,
    required this.refundedAmount,
  });
  final int bookingId;
  final String? provider;
  final bool autoRefunded;
  final String message;
  /// FCFA, jamais le forfait de service — null si aucun paiement réussi trouvé.
  final double? refundedAmount;

  factory CancelBookingResult.fromJson(Map<String, dynamic> j) =>
      CancelBookingResult(
        bookingId: (j['bookingId'] as num).toInt(),
        provider: j['provider'] as String?,
        autoRefunded: j['autoRefunded'] as bool? ?? false,
        message: j['message'] as String? ?? '',
        refundedAmount: (j['refundedAmount'] as num?)?.toDouble(),
      );
}

class AdminRefundsPage extends ConsumerStatefulWidget {
  const AdminRefundsPage({super.key});

  @override
  ConsumerState<AdminRefundsPage> createState() => _AdminRefundsPageState();
}

class _AdminRefundsPageState extends ConsumerState<AdminRefundsPage> {
  String _search = '';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();
  final Set<int> _cancelling = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndCancel(AdminBookingListItem booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 26),
            SizedBox(width: 10),
            Expanded(child: Text('Annuler cette réservation ?')),
          ],
        ),
        content: Text(
          '${booking.reference} — ${booking.customerName}\n${booking.route}\n'
          '${booking.totalPrice.toStringAsFixed(0)} FCFA\n\n'
          'Le remboursement Stripe (si applicable) sera déclenché automatiquement. '
          'Pour FedaPay, un remboursement manuel restera nécessaire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling.add(booking.id));
    try {
      final res = await ApiClient.instance.dio
          .post<Map<String, dynamic>>('/admin/bookings/${booking.id}/cancel');
      final result = CancelBookingResult.fromJson(res.data!);
      ref.invalidate(bookingListProvider((period: _kWideDefault, search: _search)));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                result.autoRefunded
                    ? Icons.check_circle_rounded
                    : Icons.info_rounded,
                color: result.autoRefunded ? AppColors.stationGreen : AppColors.warning,
                size: 26,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Réservation annulée')),
            ],
          ),
          content: Text(result.message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mobiliYellow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK', style: TextStyle(color: AppColors.mobiliBlueDeep)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'annulation : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(booking.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync =
        ref.watch(bookingListProvider((period: _kWideDefault, search: _search)));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Annulations / Remboursements',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminSectionTitle(title: 'Réservations annulables'),
          const SizedBox(height: 4),
          const Text(
            'Réservations en attente de paiement ou confirmées — le '
            'remboursement Stripe est automatique, FedaPay nécessite une '
            'action manuelle sur le dashboard FedaPay.',
            style: TextStyle(fontSize: 11, color: AppColors.gray500),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _search = v;
              _pageSize = 20;
            }),
            decoration: InputDecoration(
              hintText: 'Rechercher référence ou client...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: AppColors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
            ),
          ),
          const SizedBox(height: 10),
          listAsync.when(
            loading: () => const AdminLoadingCard(),
            error: (e, _) => AdminErrorCard(message: '$e'),
            data: (all) {
              final list =
                  all.where((b) => _cancellableStatuses.contains(b.status)).toList();
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Aucune réservation annulable trouvée',
                      style: TextStyle(color: AppColors.gray400),
                    ),
                  ),
                );
              }
              final visible = list.take(_pageSize).toList();
              final hasMore = list.length > _pageSize;
              return Column(
                children: [
                  Text(
                    '${visible.length} / ${list.length} réservation(s) annulable(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...visible.map((b) => _BookingCancelCard(
                        booking: b,
                        isCancelling: _cancelling.contains(b.id),
                        onCancel: () => _confirmAndCancel(b),
                      )),
                  if (hasMore)
                    LoadMoreButton(
                      remaining: list.length - _pageSize,
                      onTap: () => setState(() => _pageSize += 20),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BookingCancelCard extends StatelessWidget {
  const _BookingCancelCard({
    required this.booking,
    required this.isCancelling,
    required this.onCancel,
  });

  final AdminBookingListItem booking;
  final bool isCancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        booking.status == 'CONFIRMED' ? AppColors.stationGreen : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
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
                      booking.reference,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.mobiliBlueDeep,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        booking.status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${booking.customerName} — ${booking.route}',
                  style: const TextStyle(fontSize: 11, color: AppColors.gray500),
                ),
                Text(
                  '${DateFormat('dd/MM/yy HH:mm').format(booking.bookingDate)} — '
                  '${booking.totalPrice.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontSize: 10, color: AppColors.gray400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isCancelling
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.danger,
                  ),
                )
              : OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontSize: 11)),
                ),
        ],
      ),
    );
  }
}
