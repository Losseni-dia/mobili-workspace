import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/mobili_app_bar.dart';
import '../../../shared/widgets/mobili_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bookings/data/booking_service.dart';
import '../../bookings/domain/models/booking_detail.dart';
import '../../bookings/domain/models/ticket.dart';
import '../data/claim_service.dart';
import '../domain/models/claim_reason.dart';

/// Formulaire de réclamation — GÉNÉRIQUE, réutilisable pour n'importe quel
/// motif présent (ou futur) dans [ClaimReasonType]. Rien ici n'est câblé en
/// dur pour "annulation" : la page s'adapte selon [initialReason] et
/// [ClaimReasonType.requiresBooking].
///
/// Deux façons de l'ouvrir :
/// - Depuis une réservation précise (ex. bouton "Annuler" dans
///   my_bookings_page.dart) : passer [initialReason] et [initialBookingId] —
///   le motif et la réservation sont pré-sélectionnés et la réservation est
///   affichée en lecture seule (pas de resaisie).
/// - Depuis un point d'entrée générique (ex. "Signaler un problème" dans le
///   profil) : ne rien passer — l'utilisateur choisit le motif, puis, si le
///   motif l'exige, choisit sa réservation dans la liste des siennes.
class ClaimFormPage extends ConsumerStatefulWidget {
  const ClaimFormPage({
    super.key,
    this.initialReason,
    this.initialBookingId,
    this.lockReason = false,
  });

  final ClaimReasonType? initialReason;
  final int? initialBookingId;

  /// Si true, le motif n'est pas modifiable (cas "Annuler ma réservation" —
  /// on sait déjà pourquoi l'utilisateur est ici).
  final bool lockReason;

  @override
  ConsumerState<ClaimFormPage> createState() => _ClaimFormPageState();
}

class _ClaimFormPageState extends ConsumerState<ClaimFormPage> {
  late ClaimReasonType _reason;
  int? _selectedBookingId;
  BookingDetail? _selectedBooking;
  final _messageCtrl = TextEditingController();
  final _messageFocus = FocusNode();

  List<BookingDetail>? _myBookings;
  bool _loadingBookings = false;
  bool _submitting = false;
  String? _error;

  /// Uniquement pour le motif "annulation" sur une résa multi-sièges : tickets de la
  /// réservation sélectionnée, pour permettre de n'en annuler qu'une partie plutôt que
  /// toute la résa. null tant qu'aucune résa multi-sièges n'est sélectionnée ou que le
  /// chargement n'a pas encore eu lieu.
  List<Ticket>? _bookingTickets;
  bool _loadingTickets = false;
  Set<int> _selectedTicketIds = {};

  /// Tant qu'aucune réservation n'est choisie, la liste reste dépliée ; dès
  /// qu'on en sélectionne une, elle se replie pour ne montrer que celle-ci
  /// (sinon la liste peut être longue si l'utilisateur a beaucoup de
  /// réservations) — un "Changer" permet de la rouvrir.
  bool _bookingListExpanded = true;

  @override
  void initState() {
    super.initState();
    _reason = widget.initialReason ?? ClaimReasonType.other;
    _selectedBookingId = widget.initialBookingId;
    if (_reason.requiresBooking) {
      _loadBookings(preselectId: widget.initialBookingId);
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBookings({int? preselectId}) async {
    final userId = ref.read(authProvider).valueOrNull?.profile?.id;
    if (userId == null) return;
    setState(() => _loadingBookings = true);
    try {
      final bookings = await BookingService().getBookingDetailsForUser(userId);
      if (!mounted) return;
      setState(() {
        _myBookings = bookings;
        if (preselectId != null) {
          _selectedBooking =
              bookings.where((b) => b.id == preselectId).cast<BookingDetail?>().firstOrNull;
          _selectedBookingId = _selectedBooking?.id ?? preselectId;
          _bookingListExpanded = false;
        }
      });
      if (_selectedBooking != null) {
        _loadTicketsForSelectedBooking();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _myBookings = []);
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  /// Uniquement utile pour le motif annulation sur une résa multi-sièges — voir
  /// _bookingTickets. Silencieux en cas d'échec : le pire cas est de retomber sur
  /// "annuler toute la réservation" (comportement historique), jamais un blocage.
  Future<void> _loadTicketsForSelectedBooking() async {
    final booking = _selectedBooking;
    final userId = ref.read(authProvider).valueOrNull?.profile?.id;
    if (booking == null || userId == null || _reason != ClaimReasonType.cancellation) {
      setState(() {
        _bookingTickets = null;
        _selectedTicketIds = {};
      });
      return;
    }
    if (booking.numberOfSeats <= 1) {
      setState(() {
        _bookingTickets = null;
        _selectedTicketIds = {};
      });
      return;
    }
    setState(() => _loadingTickets = true);
    try {
      final allTickets = await BookingService().getTicketsForUser(userId);
      final tickets = allTickets.where((t) => t.bookingId == booking.id).toList();
      if (!mounted) return;
      setState(() {
        _bookingTickets = tickets;
        // Tout sélectionné par défaut = "annuler toute la réservation", le
        // comportement historique — l'utilisateur décoche ce qu'il veut garder.
        _selectedTicketIds = tickets.where((t) => t.isCancellable).map((t) => t.id!).toSet();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bookingTickets = null;
        _selectedTicketIds = {};
      });
    } finally {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  void _onReasonChanged(ClaimReasonType reason) {
    setState(() {
      _reason = reason;
      _selectedBookingId = null;
      _selectedBooking = null;
      _bookingListExpanded = true;
      _bookingTickets = null;
      _selectedTicketIds = {};
    });
    if (reason.requiresBooking && _myBookings == null) {
      _loadBookings();
    }
  }

  bool get _canSubmit {
    if (_submitting) return false;
    if (_messageCtrl.text.trim().isEmpty) return false;
    if (_reason.requiresBooking && _selectedBookingId == null) return false;
    if (_bookingTickets != null && _bookingTickets!.isNotEmpty && _selectedTicketIds.isEmpty) {
      return false;
    }
    return true;
  }

  /// null (résa entière) sauf si l'utilisateur a désélectionné au moins un siège
  /// annulable — dans ce cas, seuls les tickets encore cochés sont ciblés.
  Map<String, String>? get _claimDetails {
    final tickets = _bookingTickets;
    if (tickets == null || tickets.isEmpty) return null;
    final cancellableIds = tickets.where((t) => t.isCancellable).map((t) => t.id!).toSet();
    if (_selectedTicketIds.length >= cancellableIds.length) {
      // Tout est coché : équivalent à "toute la réservation", pas besoin de le préciser.
      return null;
    }
    return {'ticketIds': _selectedTicketIds.join(',')};
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ClaimService().createClaim(
        reason: _reason,
        bookingId: _selectedBookingId,
        message: _messageCtrl.text.trim(),
        details: _claimDetails,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.stationGreen, size: 26),
              SizedBox(width: 10),
              Expanded(child: Text('Réclamation envoyée')),
            ],
          ),
          content: const Text(
            'Votre demande a bien été enregistrée. Notre équipe la traitera '
            'dans les meilleurs délais.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mobiliBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Compris', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible d\'envoyer la réclamation. Réessayez.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: const MobiliAppBar(title: 'Signaler un problème', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Motif de la réclamation'),
          const SizedBox(height: 8),
          if (widget.lockReason)
            _ReasonTile(reason: _reason, selected: true, onTap: () {})
          else
            _ReasonPicker(selected: _reason, onChanged: _onReasonChanged),
          const SizedBox(height: 20),
          if (_reason.requiresBooking) ...[
            const _SectionTitle('Réservation concernée'),
            const SizedBox(height: 8),
            _BookingPicker(
              loading: _loadingBookings,
              bookings: _myBookings ?? const [],
              selectedId: _selectedBookingId,
              locked: widget.initialBookingId != null,
              lockedBooking: _selectedBooking,
              expanded: _bookingListExpanded,
              onSelected: (b) {
                setState(() {
                  _selectedBookingId = b.id;
                  _selectedBooking = b;
                  _bookingListExpanded = false;
                });
                _loadTicketsForSelectedBooking();
              },
              onChangeRequested: () => setState(() => _bookingListExpanded = true),
            ),
            if (_reason == ClaimReasonType.cancellation &&
                _selectedBooking != null &&
                _selectedBooking!.numberOfSeats > 1) ...[
              const SizedBox(height: 14),
              const _SectionTitle('Sièges à annuler'),
              const SizedBox(height: 4),
              Text(
                'Décochez les sièges que vous souhaitez garder — par défaut, toute '
                'la réservation est visée.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray500),
              ),
              const SizedBox(height: 8),
              _TicketSelector(
                loading: _loadingTickets,
                tickets: _bookingTickets ?? const [],
                selectedIds: _selectedTicketIds,
                onToggle: (id) => setState(() {
                  if (_selectedTicketIds.contains(id)) {
                    _selectedTicketIds.remove(id);
                  } else {
                    _selectedTicketIds.add(id);
                  }
                }),
              ),
            ],
            const SizedBox(height: 20),
          ],
          const _SectionTitle('Décrivez votre demande'),
          const SizedBox(height: 8),
          TextField(
            controller: _messageCtrl,
            focusNode: _messageFocus,
            maxLines: 5,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Expliquez votre situation en quelques mots…',
              filled: true,
              fillColor: AppColors.white,
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
                borderSide: const BorderSide(color: AppColors.mobiliBlue, width: 2),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: 24),
          MobiliButton(
            label: 'Envoyer la réclamation',
            onPressed: _canSubmit ? _submit : null,
            isLoading: _submitting,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.mobiliBlueDeep,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _ReasonPicker extends StatelessWidget {
  const _ReasonPicker({required this.selected, required this.onChanged});
  final ClaimReasonType selected;
  final ValueChanged<ClaimReasonType> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: ClaimReasonType.values
            .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReasonTile(
                    reason: r,
                    selected: r == selected,
                    onTap: () => onChanged(r),
                  ),
                ))
            .toList(),
      );
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.reason, required this.selected, required this.onTap});
  final ClaimReasonType reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.mobiliBlueFog : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.mobiliBlue : AppColors.gray200,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(reason.icon,
                    size: 20, color: selected ? AppColors.mobiliBlue : AppColors.gray400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(reason.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.gray700,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      )),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.mobiliBlue, size: 20),
              ],
            ),
          ),
        ),
      );
}

class _BookingPicker extends StatelessWidget {
  const _BookingPicker({
    required this.loading,
    required this.bookings,
    required this.selectedId,
    required this.locked,
    required this.lockedBooking,
    required this.expanded,
    required this.onSelected,
    required this.onChangeRequested,
  });

  final bool loading;
  final List<BookingDetail> bookings;
  final int? selectedId;
  final bool locked;
  final BookingDetail? lockedBooking;

  /// false = liste repliée, seule la réservation choisie est affichée.
  final bool expanded;
  final ValueChanged<BookingDetail> onSelected;
  final VoidCallback onChangeRequested;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      // Pré-rempli automatiquement : la réservation n'est jamais resaisie.
      return lockedBooking != null
          ? _BookingCard(booking: lockedBooking!, selected: true, onTap: null)
          : Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray200),
              ),
              child: Row(
                children: [
                  const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text('Chargement de la réservation…',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray500)),
                ],
              ),
            );
    }

    if (loading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ));
    }

    if (bookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Text('Aucune réservation trouvée.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray500)),
      );
    }

    // Une réservation est choisie et la liste est repliée : on n'affiche
    // que celle-ci, avec un lien pour revenir sur la liste complète.
    if (!expanded && selectedId != null) {
      final selected = bookings.where((b) => b.id == selectedId).cast<BookingDetail?>().firstOrNull;
      if (selected != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _BookingCard(booking: selected, selected: true, onTap: null),
            TextButton(
              onPressed: onChangeRequested,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              child: Text('Changer de réservation',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.mobiliBlue, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      }
    }

    return Column(
      children: bookings
          .map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BookingCard(
                  booking: b,
                  selected: b.id == selectedId,
                  onTap: () => onSelected(b),
                ),
              ))
          .toList(),
    );
  }
}

class _TicketSelector extends StatelessWidget {
  const _TicketSelector({
    required this.loading,
    required this.tickets,
    required this.selectedIds,
    required this.onToggle,
  });

  final bool loading;
  final List<Ticket> tickets;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (tickets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Text('Chargement des sièges…',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray500)),
      );
    }
    return Column(
      children: tickets.map((t) {
        final id = t.id;
        final cancellable = t.isCancellable && id != null;
        final selected = id != null && selectedIds.contains(id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? AppColors.mobiliBlueFog : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: cancellable ? () => onToggle(id) : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.mobiliBlue : AppColors.gray200,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cancellable
                          ? (selected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded)
                          : Icons.block_rounded,
                      color: cancellable
                          ? (selected ? AppColors.mobiliBlue : AppColors.gray400)
                          : AppColors.gray300,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Siège ${t.seatNumber} — ${t.passengerFullName}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.gray700,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              )),
                          if (!cancellable)
                            Text('Déjà ${t.status.toLowerCase()}, non annulable',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.gray400, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.selected, required this.onTap});
  final BookingDetail booking;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.mobiliBlueFog : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.mobiliBlue : AppColors.gray200,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${booking.departureCity} → ${booking.arrivalCity}',
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700, color: AppColors.gray700)),
                      const SizedBox(height: 2),
                      Text(
                          'Réf. ${booking.reference} · ${booking.formattedDate} · ${booking.formattedPrice}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray500)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.mobiliBlue, size: 20),
              ],
            ),
          ),
        ),
      );
}
