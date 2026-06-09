import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../bookings/data/booking_service.dart';
import '../../../bookings/domain/models/booking_detail.dart';

final _bookingsDetailProvider = FutureProvider.autoDispose
    .family<List<BookingDetail>, int>((ref, userId) async {
  return BookingService().getBookingDetailsForUser(userId);
});

class MyBookingsPage extends ConsumerStatefulWidget {
  const MyBookingsPage({super.key});

  @override
  ConsumerState<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends ConsumerState<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _ratedTripIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).valueOrNull?.profile;

    if (profile == null) {
      return Scaffold(
        appBar: const MobiliAppBar(
          title: 'Mes réservations',
          backRoute: '/profile',
        ),
        body: Center(
          child: Text('Connectez-vous pour voir vos réservations',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.gray500),
              textAlign: TextAlign.center),
        ),
      );
    }

    final bookingsAsync = ref.watch(_bookingsDetailProvider(profile.id));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: MobiliAppBar(
        title: 'Mes réservations',
        backRoute: '/profile',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.mobiliYellow,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          labelStyle: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
          tabs: const [
            Tab(text: 'À venir'),
            Tab(text: 'Passées'),
          ],
        ),
      ),
      body: bookingsAsync.when(
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
        data: (bookings) {
          final upcoming = bookings.where((b) => b.isUpcoming).toList()
            ..sort(
                (a, b) => a.departureDateTime.compareTo(b.departureDateTime));
          final past = bookings.where((b) => !b.isUpcoming).toList()
            ..sort(
                (a, b) => b.departureDateTime.compareTo(a.departureDateTime));

          return TabBarView(
            controller: _tabController,
            children: [
              _BookingList(
                bookings: upcoming,
                emptyMessage: 'Aucun voyage à venir',
                emptyIcon: Icons.flight_takeoff_rounded,
                ratedTripIds: _ratedTripIds,
                onRated: (tripId) => setState(() => _ratedTripIds.add(tripId)),
              ),
              _BookingList(
                bookings: past,
                emptyMessage: 'Aucun voyage passé',
                emptyIcon: Icons.history_rounded,
                ratedTripIds: _ratedTripIds,
                onRated: (tripId) => setState(() => _ratedTripIds.add(tripId)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.ratedTripIds,
    required this.onRated,
  });

  final List<BookingDetail> bookings;
  final String emptyMessage;
  final IconData emptyIcon;
  final Set<int> ratedTripIds;
  final ValueChanged<int> onRated;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
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
              child: Icon(emptyIcon, color: AppColors.mobiliBlue, size: 36),
            ),
            const SizedBox(height: 14),
            Text(emptyMessage,
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.mobiliBlueDeep)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _BookingCard(
          booking: bookings[index],
          ratedTripIds: ratedTripIds,
          onRated: onRated,
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.ratedTripIds,
    required this.onRated,
  });

  final BookingDetail booking;
  final Set<int> ratedTripIds;
  final ValueChanged<int> onRated;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(booking.status);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: _BookingPattern(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(booking.departureCity,
                                        style:
                                            AppTextStyles.titleLarge.copyWith(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        )),
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.arrow_forward_rounded,
                                        color: AppColors.mobiliYellow,
                                        size: 16),
                                  ),
                                  Flexible(
                                    child: Text(booking.arrivalCity,
                                        style:
                                            AppTextStyles.titleLarge.copyWith(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        )),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 12, color: AppColors.mobiliYellow),
                                  const SizedBox(width: 4),
                                  Text(booking.formattedDate,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.white
                                            .withValues(alpha: 0.8),
                                        fontSize: 12,
                                      )),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusConfig.$1,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(booking.status,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: statusConfig.$2,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Infos ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoItem(label: 'RÉFÉRENCE', value: booking.reference),
                        const SizedBox(height: 10),
                        _InfoItem(
                            label: 'SIÈGES',
                            value: booking.seatNumbers.join(', ')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoItem(
                          label: 'TOTAL',
                          value: booking.formattedPrice,
                          valueColor: AppColors.mobiliBlueDeep,
                        ),
                        const SizedBox(height: 10),
                        _InfoItem(
                          label: 'NB PASSAGERS',
                          value: '${booking.numberOfSeats}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Passagers (expandable) ───────────────────
            if (booking.passengerNames.isNotEmpty)
              Material(
                color: AppColors.white,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    title: Row(
                      children: [
                        const Icon(Icons.people_outline_rounded,
                            size: 16, color: AppColors.mobiliBlue),
                        const SizedBox(width: 6),
                        Text(
                          'Passagers (${booking.passengerNames.length})',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.mobiliBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    iconColor: AppColors.mobiliBlue,
                    collapsedIconColor: AppColors.gray400,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    children: booking.passengerNames
                        .map((name) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: AppColors.mobiliBlueFog,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person_rounded,
                                        size: 16, color: AppColors.mobiliBlue),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(name,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.gray700,
                                        fontSize: 13,
                                      )),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),

            // ── Escales (expandable) ─────────────────────
            if (booking.moreInfo != null && booking.moreInfo!.isNotEmpty)
              Material(
                color: AppColors.white,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    title: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.mobiliBlue),
                        const SizedBox(width: 6),
                        Text('Villes desservies',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.mobiliBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            )),
                      ],
                    ),
                    iconColor: AppColors.mobiliBlue,
                    collapsedIconColor: AppColors.mobiliBlue,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: booking.moreInfo!
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .map((stop) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: AppColors.gray200),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(stop,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 11,
                                        color: AppColors.gray600,
                                      )),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Actions ──────────────────────────────────
            if (booking.canCancel ||
                !booking.isUpcoming ||
                booking.status == 'CONFIRMED') ...[
              const Divider(height: 1, color: AppColors.gray100),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    // Voir billets
                    if (booking.status == 'CONFIRMED')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                context.go('/tickets?tripId=${booking.tripId}'),
                            icon: const Icon(Icons.confirmation_number_rounded,
                                size: 16, color: AppColors.mobiliBlueDeep),
                            label: const Text('Voir les billets'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mobiliYellow,
                              foregroundColor: AppColors.mobiliBlueDeep,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),

                    // Re-réserver
                    if (!booking.isUpcoming)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go(
                              '/?departure=${Uri.encodeComponent(booking.departureCity)}&arrival=${Uri.encodeComponent(booking.arrivalCity)}',
                            ),
                            icon: const Icon(Icons.refresh_rounded,
                                size: 16, color: AppColors.white),
                            label: const Text('Re-réserver ce trajet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mobiliBlue,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),

                    // Noter — masqué si déjà noté
                    if (!booking.isUpcoming &&
                        booking.status == 'CONFIRMED' &&
                        booking.tripId != null &&
                        !ratedTripIds.contains(booking.tripId))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showRatingDialog(context, booking.tripId),
                            icon: const Icon(Icons.star_outline_rounded,
                                size: 16),
                            label: const Text('Noter ce trajet'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.mobiliYellow,
                              side: const BorderSide(
                                  color: AppColors.mobiliYellow),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),

                    // Déjà noté
                    if (!booking.isUpcoming &&
                        booking.status == 'CONFIRMED' &&
                        booking.tripId != null &&
                        ratedTripIds.contains(booking.tripId))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.stationGreen, size: 16),
                            const SizedBox(width: 6),
                            Text('Trajet noté — merci !',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.stationGreen,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),

                    // Annuler
                    if (booking.canCancel)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmCancel(context),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Annuler la réservation'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showRatingDialog(BuildContext context, int? tripId) async {
    if (tripId == null) return;
    int selectedNote = 0;
    final commentCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Noter ce trajet',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text('${booking.departureCity} → ${booking.arrivalCity}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.gray500)),
                const SizedBox(height: 20),

                // Étoiles
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedNote = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          star <= selectedNote
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.mobiliYellow,
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),

                if (selectedNote > 0) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _noteLabel(selectedNote),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.mobiliBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Votre commentaire (optionnel)',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.gray300),
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
                          color: AppColors.mobiliBlue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedNote == 0
                        ? null
                        : () async {
                            try {
                              await _submitRating(
                                  tripId, selectedNote, commentCtrl.text);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                onRated(tripId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Merci pour votre avis ! ⭐'),
                                    backgroundColor: AppColors.stationGreen,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        e.toString().contains('déjà noté')
                                            ? 'Vous avez déjà noté ce trajet'
                                            : 'Erreur lors de l\'envoi'),
                                    backgroundColor: AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mobiliBlue,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.gray200,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Envoyer mon avis',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _noteLabel(int note) {
    switch (note) {
      case 1:
        return 'Très mauvais';
      case 2:
        return 'Mauvais';
      case 3:
        return 'Correct';
      case 4:
        return 'Bien';
      case 5:
        return 'Excellent !';
      default:
        return '';
    }
  }

  Future<void> _submitRating(int tripId, int note, String comment) async {
    final dio = ApiClient.instance.dio;
    await dio.post<void>(
      '/trips/$tripId/ratings',
      data: {
        'note': note,
        'comment': comment.trim().isEmpty ? null : comment.trim(),
      },
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler cette réservation ?'),
        content:
            Text('Voulez-vous annuler la réservation ${booking.reference} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Annulation bientôt disponible'),
                  backgroundColor: AppColors.warning,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Annuler la réservation',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  (Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'PENDING':
        return (AppColors.warningSoft, AppColors.warning);
      case 'CANCELLED':
        return (AppColors.dangerSoft, AppColors.danger);
      case 'COMPLETED':
        return (AppColors.mobiliBlueFog, AppColors.mobiliBlue);
      default:
        return (AppColors.gray100, AppColors.gray500);
    }
  }
}

class _BookingPattern extends StatelessWidget {
  static const _icons = [
    Icons.directions_bus_rounded,
    Icons.airport_shuttle_rounded,
    Icons.directions_car_rounded,
    Icons.two_wheeler_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    const cols = 5;
    const rows = 4;
    const cellW = 60.0;
    const cellH = 28.0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final icon = _icons[(r * cols + c) % _icons.length];
        final offset = (r % 2 == 0) ? 0.0 : cellW * 0.5;
        items.add(Positioned(
          left: c * cellW + offset,
          top: r * cellH,
          child:
              Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.06)),
        ));
      }
    }
    return Stack(children: items);
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

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
                fontWeight: FontWeight.w600,
                fontSize: 12,
              )),
        ],
      );
}
