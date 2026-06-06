import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_app_bar.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_loader.dart';
import '../../../trips/domain/models/trip.dart';
import '../../../trips/providers/trip_provider.dart';
import '../../data/booking_service.dart';
import '../widgets/seat_map_widget.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key, required this.trip});
  final Trip trip;

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  final List<String> _selectedSeats = [];
  final List<TextEditingController> _passengerCtrls = [];
  int _boardingIndex = 0;
  int _alightingIndex = 0;
  int _extraBags = 0;
  late List<String> _stopLabels;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _stopLabels = _buildStopLabels();
    _alightingIndex = _stopLabels.length - 1;

    _appLinks = AppLinks();
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      if (uri.host == 'payment' && uri.path == '/success') {
        ref.read(bookingNotifierProvider.notifier).verifyAfterReturn();
      }
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    for (final c in _passengerCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _buildStopLabels() {
    final dep = widget.trip.departureCity;
    final arr = widget.trip.arrivalCity;
    final more = widget.trip.moreInfo ?? '';
    final labels = <String>[dep];
    if (more.isNotEmpty) {
      for (final city in more.split(',')) {
        final t = city.trim();
        if (t.isNotEmpty && t.toLowerCase() != dep.toLowerCase()) {
          labels.add(t[0].toUpperCase() + t.substring(1).toLowerCase());
        }
      }
    }
    if (arr.toLowerCase() != labels.last.toLowerCase()) {
      labels.add(arr);
    }
    return labels;
  }

  double _pricePerSeat() {
    final fares = widget.trip.legFares;
    if (fares != null && fares.isNotEmpty) {
      double total = 0;
      for (var i = _boardingIndex;
          i < _alightingIndex && i < fares.length;
          i++) {
        total += fares[i].priceXof;
      }
      if (total > 0) return total;
    }
    return widget.trip.priceXof;
  }

  double _luggageFee() => _extraBags * (widget.trip.extraHoldBagPrice ?? 0);

  double _totalPrice() =>
      _selectedSeats.length * _pricePerSeat() + _luggageFee();

  int _maxExtraBags() =>
      _selectedSeats.length * widget.trip.maxExtraHoldBagsPerPassenger;

  void _onSeatTap(int seatNumber, List<int> occupied) {
    if (occupied.contains(seatNumber) ||
        occupied.contains(seatNumber.toString())) return;
    final seat = '$seatNumber';
    setState(() {
      if (_selectedSeats.contains(seat)) {
        final idx = _selectedSeats.indexOf(seat);
        _selectedSeats.remove(seat);
        _passengerCtrls[idx].dispose();
        _passengerCtrls.removeAt(idx);
      } else {
        _selectedSeats.add(seat);
        _passengerCtrls.add(TextEditingController());
      }
      if (_extraBags > _maxExtraBags()) _extraBags = _maxExtraBags();
    });
  }

  bool get _isValid {
    if (_selectedSeats.isEmpty) return false;
    if (_alightingIndex <= _boardingIndex) return false;
    for (final c in _passengerCtrls) {
      if (c.text.trim().isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingNotifierProvider);
    final occupiedAsync = ref.watch(occupiedSeatsProvider(
      OccupiedSeatsParams(
        tripId: widget.trip.id,
        boardingStopIndex: _boardingIndex,
        alightingStopIndex: _alightingIndex,
      ),
    ));

    ref.listen<BookingState>(bookingNotifierProvider, (_, next) {
      if (next.step == BookingStep.done) _showSuccess();
    });

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: MobiliAppBar(
        title: 'Réservation',
        backRoute: '/',
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Résumé trajet ──────────────────────
                  _TripSummary(trip: widget.trip),
                  const SizedBox(height: 16),

                  // ── Segment embarquement/descente ──────
                  if (_stopLabels.length > 2) ...[
                    _SectionTitle(
                        icon: Icons.route_rounded, label: 'Votre tronçon'),
                    const SizedBox(height: 10),
                    _SegmentSelector(
                      stopLabels: _stopLabels,
                      boardingIndex: _boardingIndex,
                      alightingIndex: _alightingIndex,
                      pricePerSeat: _pricePerSeat(),
                      onBoardingChanged: (i) => setState(() {
                        _boardingIndex = i;
                        if (_alightingIndex <= i) _alightingIndex = i + 1;
                      }),
                      onAlightingChanged: (i) =>
                          setState(() => _alightingIndex = i),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Sièges ─────────────────────────────
                  _SectionTitle(
                      icon: Icons.event_seat_rounded,
                      label: 'Choisissez vos sièges'),
                  const SizedBox(height: 10),
                  occupiedAsync.when(
                    loading: () => const MobiliLoader(),
                    error: (_, __) =>
                        const Text('Erreur de chargement des sièges'),
                    data: (occupied) => SeatMapWidget(
                      totalSeats: widget.trip.totalSeats,
                      occupied: occupied,
                      selected: _selectedSeats,
                      onTap: (n) => _onSeatTap(n, occupied),
                      vehicleType: widget.trip.vehicleType,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Noms passagers ─────────────────────
                  if (_selectedSeats.isNotEmpty) ...[
                    _SectionTitle(
                        icon: Icons.people_outline_rounded,
                        label: 'Noms des passagers'),
                    const SizedBox(height: 10),
                    ...List.generate(
                      _selectedSeats.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PassengerField(
                          seatNumber: _selectedSeats[i],
                          controller: _passengerCtrls[i],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // ── Bagages ────────────────────────────
                  if ((widget.trip.extraHoldBagPrice ?? 0) > 0 &&
                      _selectedSeats.isNotEmpty) ...[
                    _SectionTitle(
                        icon: Icons.luggage_rounded,
                        label: 'Bagages supplémentaires'),
                    const SizedBox(height: 10),
                    _BaggageSelector(
                      extraBags: _extraBags,
                      maxBags: _maxExtraBags(),
                      pricePerBag: widget.trip.extraHoldBagPrice ?? 0,
                      onChanged: (v) => setState(() => _extraBags = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── Barre prix + paiement ──────────────────
          _PriceBar(
            selectedCount: _selectedSeats.length,
            pricePerSeat: _pricePerSeat(),
            luggageFee: _luggageFee(),
            total: _totalPrice(),
            isLoading: bookingState.isLoading,
            isValid: _isValid,
            onPay: () async {
              await ref.read(bookingNotifierProvider.notifier).createAndPay(
                    CreateBookingRequest(
                      tripId: widget.trip.id,
                      seatNumber: int.parse(_selectedSeats.first),
                      boardingStopIndex: _boardingIndex,
                      alightingStopIndex: _alightingIndex,
                    ),
                  );
              final state = ref.read(bookingNotifierProvider);
              if (state.paymentUrl != null && mounted) {
                final uri = Uri.parse(state.paymentUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  // verifyAfterReturn() déclenché via deep link
                  // mobili://payment/success?bookingId=X
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.stationGreen, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Réservation confirmée !',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content:
            const Text('Votre réservation Mobili est validée. Bon voyage !'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/my-bookings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mobiliBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Voir mes réservations',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Résumé trajet
// ─────────────────────────────────────────────────────────────────────────────

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(trip.departureCity,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: AppColors.mobiliYellow, size: 16),
                    ),
                    Flexible(
                      child: Text(trip.arrivalCity,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(trip.formattedDepartureFull,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.white.withValues(alpha: 0.75),
                    )),
                if (trip.partnerName != null) ...[
                  const SizedBox(height: 2),
                  Text(trip.partnerName!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.mobiliYellow.withValues(alpha: 0.9),
                        fontSize: 11,
                      )),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mobiliYellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${trip.availableSeats} places',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.mobiliBlueDeep,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur tronçon
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentSelector extends StatelessWidget {
  const _SegmentSelector({
    required this.stopLabels,
    required this.boardingIndex,
    required this.alightingIndex,
    required this.pricePerSeat,
    required this.onBoardingChanged,
    required this.onAlightingChanged,
  });

  final List<String> stopLabels;
  final int boardingIndex;
  final int alightingIndex;
  final double pricePerSeat;
  final ValueChanged<int> onBoardingChanged;
  final ValueChanged<int> onAlightingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Embarquement',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.gray400,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        )),
                    const SizedBox(height: 4),
                    _StopDropdown(
                      value: boardingIndex,
                      options: stopLabels
                          .sublist(0, stopLabels.length - 1)
                          .asMap()
                          .entries
                          .map((e) => MapEntry(e.key, e.value))
                          .toList(),
                      onChanged: onBoardingChanged,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    color: AppColors.mobiliBlue, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Descente',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.gray400,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        )),
                    const SizedBox(height: 4),
                    _StopDropdown(
                      value: alightingIndex,
                      options: stopLabels
                          .sublist(boardingIndex + 1)
                          .asMap()
                          .entries
                          .map((e) =>
                              MapEntry(boardingIndex + 1 + e.key, e.value))
                          .toList(),
                      onChanged: onAlightingChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.mobiliBlueFog,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sell_outlined,
                    size: 14, color: AppColors.mobiliBlue),
                const SizedBox(width: 6),
                Text(
                  'Prix pour ce tronçon : ${pricePerSeat.toStringAsFixed(0)} FCFA / place',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.mobiliBlue,
                    fontWeight: FontWeight.w600,
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
}

class _StopDropdown extends StatelessWidget {
  const _StopDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<MapEntry<int, String>> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.gray400),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.mobiliBlueDeep,
            fontSize: 13,
          ),
          items: options
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Champ nom passager
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerField extends StatelessWidget {
  const _PassengerField({
    required this.seatNumber,
    required this.controller,
    required this.onChanged,
  });

  final String seatNumber;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.mobiliYellow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(seatNumber,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.mobiliBlueDeep,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textCapitalization: TextCapitalization.words,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.mobiliBlueDeep),
            decoration: InputDecoration(
              hintText: 'Nom du passager',
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.gray300),
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  size: 18, color: AppColors.gray400),
              filled: true,
              fillColor: AppColors.white,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                borderSide:
                    const BorderSide(color: AppColors.mobiliBlue, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur bagages
// ─────────────────────────────────────────────────────────────────────────────

class _BaggageSelector extends StatelessWidget {
  const _BaggageSelector({
    required this.extraBags,
    required this.maxBags,
    required this.pricePerBag,
    required this.onChanged,
  });

  final int extraBags;
  final int maxBags;
  final double pricePerBag;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          const Icon(Icons.luggage_rounded,
              color: AppColors.mobiliBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bagages soute supplémentaires',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w600,
                    )),
                Text(
                    '${pricePerBag.toStringAsFixed(0)} FCFA / bagage · max $maxBags',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.gray400,
                      fontSize: 11,
                    )),
              ],
            ),
          ),
          Row(
            children: [
              _CountBtn(
                icon: Icons.remove_rounded,
                onTap: extraBags > 0 ? () => onChanged(extraBags - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$extraBags',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                    )),
              ),
              _CountBtn(
                icon: Icons.add_rounded,
                onTap:
                    extraBags < maxBags ? () => onChanged(extraBags + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBtn extends StatelessWidget {
  const _CountBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: onTap != null ? AppColors.mobiliBlueFog : AppColors.gray100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18,
              color: onTap != null ? AppColors.mobiliBlue : AppColors.gray300),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre prix + bouton paiement
// ─────────────────────────────────────────────────────────────────────────────

class _PriceBar extends StatelessWidget {
  const _PriceBar({
    required this.selectedCount,
    required this.pricePerSeat,
    required this.luggageFee,
    required this.total,
    required this.isLoading,
    required this.isValid,
    required this.onPay,
  });

  final int selectedCount;
  final double pricePerSeat;
  final double luggageFee;
  final double total;
  final bool isLoading;
  final bool isValid;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow:  [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$selectedCount siège${selectedCount > 1 ? 's' : ''} × ${pricePerSeat.toStringAsFixed(0)} FCFA',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.gray500),
                ),
                Text(
                  '${(selectedCount * pricePerSeat).toStringAsFixed(0)} FCFA',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.gray600),
                ),
              ],
            ),
            if (luggageFee > 0) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bagages',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.gray500)),
                  Text(
                    '${luggageFee.toStringAsFixed(0)} FCFA',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.gray600),
                  ),
                ],
              ),
            ],
            const Divider(height: 12, color: AppColors.gray100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  '${total.toStringAsFixed(0)} FCFA',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.mobiliBlueDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          MobiliButton(
            label: isValid
                ? 'Payer ${total.toStringAsFixed(0)} FCFA via FedaPay'
                : selectedCount == 0
                    ? 'Sélectionnez un siège'
                    : 'Renseignez les noms des passagers',
            enabled: isValid && !isLoading,
            isLoading: isLoading,
            onPressed: isValid ? onPay : null,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mobiliBlue),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.mobiliBlueDeep,
                fontWeight: FontWeight.w700,
              )),
        ],
      );
}
