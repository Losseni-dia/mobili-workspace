import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobili/features/bookings/presentation/pages/booking_receipt_page.dart';
import 'package:mobili/features/bookings/presentation/pages/payment_webview_page.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../bookings/data/booking_service.dart';
import '../../../bookings/domain/models/booking_detail.dart';
import '../../../bookings/domain/models/payment_request.dart';
import '../../../claims/domain/models/claim_reason.dart';
import '../../../claims/presentation/claim_form_page.dart';

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
  int? _highlightedBookingId;
  final Map<int, GlobalKey> _cardKeys = {};

  bool _readQueryParam = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // GoRouterState.of(context) a besoin que le contexte soit pleinement
    // rattaché à l'arbre de routes — ce n'est pas encore le cas dans
    // initState(), d'où le déplacement ici, avec un verrou pour ne lire
    // le paramètre qu'une seule fois.
    if (!_readQueryParam) {
      _readQueryParam = true;
      final uri = GoRouterState.of(context).uri;
      final bookingIdParam = uri.queryParameters['bookingId'];
      if (bookingIdParam != null) {
        _highlightedBookingId = int.tryParse(bookingIdParam);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int bookingId) =>
      _cardKeys.putIfAbsent(bookingId, () => GlobalKey());

  void _scrollToHighlighted() {
    final id = _highlightedBookingId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cardKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
      // On efface le surlignage après quelques secondes.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightedBookingId = null);
      });
    });
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
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: MobiliAppBar(
        title: 'Mes réservations',
        backRoute: '/profile',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.mobiliBlue,
          indicatorWeight: 3,
          labelColor: AppColors.mobiliBlueDeep,
          unselectedLabelColor: AppColors.mobiliBlueDeep.withValues(alpha: 0.5),
          labelStyle: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
          tabs: const [
            Tab(text: 'À venir'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: MobiliIconPattern(
              color: AppColors.mobiliBlueDeep,
              cols: 5,
              rows: 14,
              iconSize: 26,
              alpha: 0.14,
            ),
          ),
          bookingsAsync.when(
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
              final upcoming = bookings
                  .where((b) => b.belongsToUpcoming)
                  .toList()
                ..sort((a, b) =>
                    a.departureDateTime.compareTo(b.departureDateTime));
              final past = bookings.where((b) => !b.belongsToUpcoming).toList()
                ..sort((a, b) =>
                    b.departureDateTime.compareTo(a.departureDateTime));

              // Si la réservation surlignée est dans "Passées", on bascule
              // automatiquement sur cet onglet pour qu'elle soit visible.
              if (_highlightedBookingId != null) {
                final isPast = past.any((b) => b.id == _highlightedBookingId);
                if (isPast && _tabController.index != 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _tabController.animateTo(1);
                  });
                }
              }
              _scrollToHighlighted();

              return TabBarView(
                controller: _tabController,
                children: [
                  _BookingList(
                    bookings: upcoming,
                    emptyMessage: 'Aucun voyage à venir',
                    emptyIcon: Icons.flight_takeoff_rounded,
                    ratedTripIds: _ratedTripIds,
                    onRated: (tripId) =>
                        setState(() => _ratedTripIds.add(tripId)),
                    highlightedBookingId: _highlightedBookingId,
                    keyFor: _keyFor,
                  ),
                  _BookingList(
                    bookings: past,
                    emptyMessage: 'Aucun voyage passé',
                    emptyIcon: Icons.history_rounded,
                    ratedTripIds: _ratedTripIds,
                    onRated: (tripId) =>
                        setState(() => _ratedTripIds.add(tripId)),
                    highlightedBookingId: _highlightedBookingId,
                    keyFor: _keyFor,
                  ),
                ],
              );
            },
          ),
        ],
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
    this.highlightedBookingId,
    required this.keyFor,
  });

  final List<BookingDetail> bookings;
  final String emptyMessage;
  final IconData emptyIcon;
  final Set<int> ratedTripIds;
  final ValueChanged<int> onRated;
  final int? highlightedBookingId;
  final GlobalKey Function(int bookingId) keyFor;

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
      itemBuilder: (context, index) {
        final b = bookings[index];
        return Padding(
          key: keyFor(b.id),
          padding: const EdgeInsets.only(bottom: 14),
          child: _BookingCard(
            booking: b,
            ratedTripIds: ratedTripIds,
            onRated: onRated,
            isHighlighted: b.id == highlightedBookingId,
          ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.ratedTripIds,
    required this.onRated,
    this.isHighlighted = false,
  });

  final BookingDetail booking;
  final Set<int> ratedTripIds;
  final ValueChanged<int> onRated;
  final bool isHighlighted;

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
          border: Border.all(
            color: isHighlighted ? AppColors.mobiliBlue : AppColors.gray200,
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: AppColors.mobiliBlue.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [
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
                          child: Text(_statusLabel(booking.status),
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
                          // Montant de la réservation seule (tickets), pas le total payé
                          // (forfait + bagages inclus) — ce détail complet reste visible sur
                          // le reçu (icône reçu ci-dessus).
                          label: 'RÉSERVATION',
                          value: booking.formattedTicketsAmount,
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

            // ── Covoiturage : en attente du conducteur ────
            if (booking.isPendingDriverApproval)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'En attente de la réponse du conducteur (24h max).',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Covoiturage : à payer sous 30 min ─────────
            if (booking.isAwaitingPayment)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _payNow(context),
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Payer maintenant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mobiliBlue,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
                                size: 16, color: AppColors.white),
                            label: const Text('Voir les billets'),
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

                    // Voir reçu — remplace l'icône reçu qui était en haut de la carte,
                    // plus visible ici comme action à part entière.
                    if (booking.status == 'CONFIRMED')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    BookingReceiptPage(booking: booking),
                              ),
                            ),
                            icon: const Icon(Icons.receipt_long_rounded,
                                size: 16),
                            label: const Text('Voir le reçu'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.mobiliBlue,
                              side:
                                  const BorderSide(color: AppColors.mobiliBlue),
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

  // L'annulation en libre-service (avec remboursement automatique) n'existe
  // pas côté app : seul un endpoint admin existe pour l'instant
  // (POST /admin/bookings/{id}/cancel — voir MobiliPro, AdminRefundsPage).
  // On passe donc par le système de réclamation générique : motif et
  // réservation sont pré-remplis, l'admin traite la demande côté MobiliPro
  // et déclenche l'annulation/remboursement lui-même après review.
  Future<void> _confirmCancel(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClaimFormPage(
          initialReason: ClaimReasonType.cancellation,
          initialBookingId: booking.id,
          lockReason: true,
        ),
      ),
    );
  }

  Future<void> _payNow(BuildContext context) async {
    // 1. Choix du provider via une dialog simple
    final provider = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir un moyen de paiement'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'FEDAPAY'),
            child: const ListTile(
              leading: Icon(Icons.money, color: AppColors.mobiliBlue),
              title: Text('Mobile Money'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'STRIPE'),
            child: const ListTile(
              leading: Icon(Icons.credit_card, color: AppColors.mobiliBlue),
              title: Text('Carte bancaire'),
            ),
          ),
        ],
      ),
    );

    if (provider == null) return; // Annulé

    try {
      final service = BookingService();
      final request = PaymentRequest(provider: provider);
      final response = await service.checkout(booking.id, request);
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewPage(
              paymentUrl: response.paymentUrl,
              providerLabel:
                  provider == 'STRIPE' ? 'Carte bancaire' : 'Mobile Money',
              onSuccess: () async {
                try {
                  final result = await service.pollUntilConfirmed(
                    booking.id,
                  );
                  if (context.mounted) {
                    if (result.confirmed) {
                      _showPaymentConfirmed(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Paiement non confirmé. Réessayez ou contactez le support.'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur de vérification : $e'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              onCancel: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du paiement : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showPaymentConfirmed(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.stationGreen, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text('Réservation confirmée !',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: const Text('Votre paiement a été confirmé. Bon voyage !'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/tickets?tripId=${booking.tripId}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mobiliBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Voir mon billet',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING_DRIVER_APPROVAL':
        return 'En attente du conducteur';
      case 'AWAITING_PAYMENT':
        return 'À payer';
      case 'REJECTED_BY_DRIVER':
        return 'Refusée';
      case 'EXPIRED':
        return 'Expirée';
      case 'PENDING':
        return 'En attente';
      case 'CONFIRMED':
        return 'Confirmée';
      case 'CANCELLED':
        return 'Annulée';
      case 'COMPLETED':
        return 'Terminée';
      default:
        return status;
    }
  }

  (Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'PENDING':
      case 'PENDING_DRIVER_APPROVAL':
        return (AppColors.warningSoft, AppColors.warning);
      case 'AWAITING_PAYMENT':
        return (
          AppColors.mobiliYellow.withValues(alpha: 0.2),
          AppColors.mobiliBlueDeep
        );
      case 'CANCELLED':
      case 'REJECTED_BY_DRIVER':
      case 'EXPIRED':
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
