import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/booking_detail.dart';

class BookingReceiptPage extends StatelessWidget {
  const BookingReceiptPage({super.key, required this.booking});
  final BookingDetail booking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: const MobiliAppBar(
        title: 'Reçu',
        showBackButton: true,
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
                    Expanded(
                      child: Text(
                        booking.tripRoute,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.mobiliBlueDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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

                // ── Détail transport ──────────────────────
               _ReceiptRow(
                  label:
                      'Transport (${booking.numberOfSeats} place${booking.numberOfSeats > 1 ? 's' : ''} × ${(booking.transportTotal / booking.numberOfSeats).toStringAsFixed(0)} FCFA)',
                  value: booking.formattedTransportTotal,
                ),

                // ── Détail bagages (si présents) ──────────
                if (booking.extraHoldBags > 0) ...[
                  const SizedBox(height: 10),
                  _ReceiptRow(
                    label:
                        'Bagages supplémentaires (${booking.extraHoldBags} bagage${booking.extraHoldBags > 1 ? 's' : ''})',
                    value: booking.formattedLuggageFee,
                  ),
                ],

                const SizedBox(height: 16),
                const _DashedLine(),
                const SizedBox(height: 16),

                // ── Total ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total payé',
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
