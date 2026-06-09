import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../bookings/data/booking_service.dart';
import '../../../bookings/domain/models/ticket.dart';

final _ticketsProvider =
    FutureProvider.autoDispose.family<List<Ticket>, int>((ref, userId) async {
  return BookingService().getTicketsForUser(userId);
});

class MyTicketsPage extends ConsumerWidget {
  const MyTicketsPage({super.key, this.filterTripId});
  final int? filterTripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).valueOrNull?.profile;

    if (profile == null) {
      return const Scaffold(
       appBar: MobiliAppBar(
          title: 'Mes billets',
          backRoute: '/profile',
        ),
        body: Center(child: Text('Non connecté')),
      );
    }

    final ticketsAsync = ref.watch(_ticketsProvider(profile.id));

    return Scaffold(
      backgroundColor: AppColors.gray50,
     appBar: const MobiliAppBar(
        title: 'Mes billets',
        backRoute: '/profile',
      ),
      body: ticketsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 48),
                const SizedBox(height: 12),
                Text('Erreur : $e',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.gray500),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.mobiliBlueFog,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.confirmation_number_outlined,
                        color: AppColors.mobiliBlue, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text('Aucun billet',
                      style: AppTextStyles.titleLarge
                          .copyWith(color: AppColors.mobiliBlueDeep)),
                  const SizedBox(height: 8),
                  Text('Vos billets apparaîtront ici après réservation.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.gray400),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }
          final filtered = filterTripId != null
              ? tickets.where((t) => t.tripId == filterTripId).toList()
              : tickets;
          return _TicketsList(tickets: filtered);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Liste avec suppression locale
// ─────────────────────────────────────────────────────────────────────────────

class _TicketsList extends StatefulWidget {
  const _TicketsList({required this.tickets});
  final List<Ticket> tickets;

  @override
  State<_TicketsList> createState() => _TicketsListState();
}

class _TicketsListState extends State<_TicketsList> {
  late List<Ticket> _tickets;

  @override
  void initState() {
    super.initState();
    _tickets = List.from(widget.tickets);
  }

  void _remove(int index) {
    setState(() => _tickets.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.confirmation_number_outlined,
                color: AppColors.mobiliBlue, size: 48),
            const SizedBox(height: 12),
            Text('Aucun billet',
                style: AppTextStyles.titleLarge
                    .copyWith(color: AppColors.mobiliBlueDeep)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      itemBuilder: (context, index) =>
          NotificationListener<_DeleteNotification>(
        onNotification: (notif) {
          final idx = _tickets
              .indexWhere((t) => t.ticketNumber == notif.ticket.ticketNumber);
          if (idx != -1) _remove(idx);
          return true;
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _TicketCard(ticket: _tickets[index]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte billet
// ─────────────────────────────────────────────────────────────────────────────

class _TicketCard extends StatefulWidget {
  const _TicketCard({required this.ticket});
  final Ticket ticket;

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  final _repaintKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareTicket() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/billet_${widget.ticket.ticketNumber}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Mon billet Mobili — ${widget.ticket.departureCity} → ${widget.ticket.arrivalCity}\n${widget.ticket.ticketNumber}',
      );
    } finally {
      setState(() => _isSharing = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce billet ?'),
        content: const Text('Ce billet sera supprimé de votre liste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      _DeleteNotification(ticket: widget.ticket).dispatch(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final statusConfig = _statusConfig(ticket.status);

    return Column(
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Header bleu ──────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ticket.partnerName
                                .replaceAll(RegExp(r'\s*\(.*?\)\s*'), ''),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              fontSize: 11,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusConfig.$1,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(ticket.status,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: statusConfig.$2,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ticket.departureCity,
                                    style:
                                        AppTextStyles.headlineMedium.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                    )),
                                Text('Départ',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.white
                                          .withValues(alpha: 0.6),
                                      fontSize: 11,
                                    )),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              const Icon(Icons.directions_bus_rounded,
                                  color: AppColors.mobiliYellow, size: 26),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(
                                  6,
                                  (_) => Container(
                                    width: 5,
                                    height: 2,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.white
                                          .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(ticket.arrivalCity,
                                    style:
                                        AppTextStyles.headlineMedium.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                    ),
                                    textAlign: TextAlign.right),
                                Text('Arrivée',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.white
                                          .withValues(alpha: 0.6),
                                      fontSize: 11,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (ticket.boardingPoint.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                AppColors.mobiliYellow.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Text('📍', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Embarquement : ${ticket.boardingPoint}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                _DashedDivider(),

                // ── Infos ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoItem(
                                label: 'DATE', value: ticket.formattedDate),
                            const SizedBox(height: 12),
                            _InfoItem(
                                label: 'PASSAGER',
                                value: ticket.passengerFullName),
                            const SizedBox(height: 12),
                            _InfoItem(
                              label: 'PRIX',
                              value: ticket.formattedPrice,
                              valueColor: AppColors.mobiliBlueDeep,
                            ),
                            const SizedBox(height: 12),
                            _InfoItem(
                                label: 'VÉHICULE',
                                value: ticket.vehiculePlateNumber),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('SIÈGE',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.gray400,
                                fontSize: 9,
                                letterSpacing: 0.8,
                              )),
                          const SizedBox(height: 6),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.mobiliYellow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(ticket.seatNumber,
                                  style: AppTextStyles.headlineMedium.copyWith(
                                    color: AppColors.mobiliBlueDeep,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 26,
                                  )),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _DashedDivider(),

                // ── QR Code ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      Text('SCANNEZ À L\'EMBARQUEMENT',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.gray400,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          )),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gray100),
                          boxShadow: const [
                            BoxShadow(color: Color(0x08000000), blurRadius: 8),
                          ],
                        ),
                        child: QrImageView(
                          data: ticket.qrCodeData,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.mobiliBlueFog,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          ticket.ticketNumber,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.mobiliBlue,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Boutons icônes ronds avec overlay ─────────────
        // ── Boutons icônes ronds avec overlay ─────────────
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconBtn(
                icon: Icons.share_rounded,
                color: AppColors.mobiliBlue,
                filled: false,
                tooltip: 'Partager',
                onTap: _isSharing ? null : _shareTicket,
                isLoading: _isSharing,
              ),
              const SizedBox(width: 12),
              _IconBtn(
                icon: Icons.download_rounded,
                color: AppColors.mobiliBlue,
                filled: true,
                tooltip: 'Télécharger',
                onTap: _isSharing ? null : _shareTicket,
              ),
              const SizedBox(width: 12),
              _IconBtn(
                icon: Icons.delete_outline_rounded,
                color: AppColors.danger,
                filled: false,
                tooltip: 'Supprimer',
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  (Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'VALIDÉ':
      case 'CONFIRMED':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'PENDING':
      case 'EN ATTENTE':
        return (AppColors.warningSoft, AppColors.warning);
      case 'CANCELLED':
      case 'ANNULÉ':
        return (AppColors.dangerSoft, AppColors.danger);
      default:
        return (AppColors.mobiliBlueFog, AppColors.mobiliBlue);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification suppression locale
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteNotification extends Notification {
  final Ticket ticket;
  const _DeleteNotification({required this.ticket});
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton icône rond avec overlay ripple
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.filled,
    required this.tooltip,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final Color color;
  final bool filled;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: color.withValues(alpha: 0.25),
          highlightColor: color.withValues(alpha: 0.12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: filled ? color : AppColors.white,
              shape: BoxShape.circle,
              border: filled ? null : Border.all(color: color, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    ),
                  )
                : Icon(icon, color: filled ? AppColors.white : color, size: 22),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    this.valueColor,
  }) : valueBold = false;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.gray400,
                fontSize: 9,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 2),
          Text(value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: valueColor ?? AppColors.gray700,
                fontWeight: valueBold ? FontWeight.w900 : FontWeight.w600,
                fontSize: valueBold ? 16 : 13,
              )),
        ],
      );
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.gray50,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dashCount = (constraints.maxWidth / 9).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  dashCount,
                  (_) => Container(
                    width: 5,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: AppColors.gray200,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.gray50,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
