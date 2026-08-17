import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/booking_detail.dart';

class BookingReceiptPage extends StatelessWidget {
  const BookingReceiptPage({super.key, required this.booking});
  final BookingDetail booking;

  (Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'COMPLETED':
        return (AppColors.mobiliBlueFog, AppColors.mobiliBlue);
      case 'CANCELLED':
      case 'REJECTED_BY_DRIVER':
      case 'EXPIRED':
        return (AppColors.dangerSoft, AppColors.danger);
      default:
        return (AppColors.gray100, AppColors.gray500);
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Confirmée';
      case 'COMPLETED':
        return 'Terminée';
      case 'CANCELLED':
        return 'Annulée';
      case 'REJECTED_BY_DRIVER':
        return 'Refusée';
      case 'EXPIRED':
        return 'Expirée';
      default:
        return status;
    }
  }

  void _share() {
    final buffer = StringBuffer()
      ..writeln('Reçu Mobili — ${booking.tripRoute}')
      ..writeln('Référence : ${booking.reference}')
      ..writeln('Départ : ${booking.formattedDate}')
      ..writeln('Montant payé : ${booking.formattedPrice}');
    if (booking.passengerNames.isNotEmpty) {
      buffer.writeln('Passagers :');
      for (final e in booking.passengerNames.asMap().entries) {
        final seat = e.key < booking.seatNumbers.length
            ? booking.seatNumbers[e.key]
            : '—';
        buffer.writeln('  - ${e.value} (siège $seat)');
      }
    }
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(booking.status);
    return Scaffold(
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: MobiliAppBar(
        title: 'Reçu',
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded, color: AppColors.white),
            tooltip: 'Partager',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 12,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.mobiliBlueFog,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_bus_rounded,
                          color: AppColors.mobiliBlue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        booking.tripRoute,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.mobiliBlueDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusConfig.$1,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_statusLabel(booking.status),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: statusConfig.$2,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  booking.formattedDate,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.gray500),
                ),
                const SizedBox(height: 6),
                Text(
                  'Réf. ${booking.reference}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.gray400),
                ),
                const SizedBox(height: 20),
                const _DashedLine(),
                const SizedBox(height: 16),

                // ── Bagages (si présents) — seul poste à part entière ─────
                // choisi par le passager, le reste (forfait de service) n'a
                // pas sa place ici : juste le montant total payé.
                if (booking.extraHoldBags > 0) ...[
                  _ReceiptRow(
                    label:
                        'Bagages supplémentaires (${booking.extraHoldBags} bagage${booking.extraHoldBags > 1 ? 's' : ''})',
                    value: booking.formattedLuggageFee,
                  ),
                  const SizedBox(height: 16),
                  const _DashedLine(),
                  const SizedBox(height: 16),
                ],

                // ── Total ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Montant total',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.mobiliBlueDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      booking.formattedPrice,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.mobiliBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${booking.numberOfSeats} place${booking.numberOfSeats > 1 ? 's' : ''}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.gray400),
                ),

                if (booking.passengerNames.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _DashedLine(),
                  const SizedBox(height: 16),
                  Text('PASSAGERS',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.gray400,
                        letterSpacing: 0.8,
                        fontSize: 10,
                      )),
                  const SizedBox(height: 8),
                  ...booking.passengerNames.asMap().entries.map((e) {
                    final seat = e.key < booking.seatNumbers.length
                        ? booking.seatNumbers[e.key]
                        : '—';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.value,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.gray700)),
                          Text('Siège $seat',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.gray400)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Acheté le ${DateFormat('dd/MM/yyyy à HH:mm').format(booking.bookingDate)}',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.gray600)),
          ),
          Text(value,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.mobiliBlueDeep,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final dashCount = (constraints.maxWidth / 8).floor();
          return Row(
            children: List.generate(
              dashCount,
              (_) => Expanded(
                child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: AppColors.gray200),
              ),
            ),
          );
        },
      );
}
