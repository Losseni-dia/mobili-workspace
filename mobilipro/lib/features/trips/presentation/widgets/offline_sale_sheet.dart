import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/features/trips/presentation/pages/trips_gare_page.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle stop
// ─────────────────────────────────────────────────────────────────────────────

class TripStop {
  const TripStop({required this.stopIndex, required this.cityLabel});
  final int stopIndex;
  final String cityLabel;

  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
    stopIndex: json['stopIndex'] as int,
    cityLabel: json['cityLabel'] as String? ?? '',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _occupiedSeatsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, tripId) async {
      final response = await ApiClient.instance.dio.get<List<dynamic>>(
        '/bookings/trips/$tripId/occupied-seats',
      );
      return (response.data ?? []).map((e) => e.toString()).toList();
    });

final _tripStopsProvider = FutureProvider.autoDispose
    .family<List<TripStop>, int>((ref, tripId) async {
      final response = await ApiClient.instance.dio.get<List<dynamic>>(
        '/trips/$tripId/stops',
      );
      return (response.data ?? [])
          .map((e) => TripStop.fromJson(e as Map<String, dynamic>))
          .toList();
    });

// ─────────────────────────────────────────────────────────────────────────────
// Sheet vente directe
// ─────────────────────────────────────────────────────────────────────────────

class OfflineSaleSheet extends ConsumerStatefulWidget {
  const OfflineSaleSheet({
    super.key,
    required this.trip,
    required this.onSuccess,
  });
  final TripItem trip;
  final VoidCallback onSuccess;

  @override
  ConsumerState<OfflineSaleSheet> createState() => _OfflineSaleSheetState();
}

class _OfflineSaleSheetState extends ConsumerState<OfflineSaleSheet> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _selectedSeats = [];
  final Map<String, TextEditingController> _nameControllers = {};
  int _boardingStopIndex = 0;
  int? _alightingStopIndex;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleSeat(int seatNum, List<TripStop> stops) {
    final seat = '$seatNum';
    setState(() {
      if (_selectedSeats.contains(seat)) {
        _selectedSeats.remove(seat);
        _nameControllers[seat]?.dispose();
        _nameControllers.remove(seat);
      } else {
        _selectedSeats.add(seat);
        _nameControllers[seat] = TextEditingController();
      }
      // init alighting au dernier stop par défaut
      if (_alightingStopIndex == null && stops.isNotEmpty) {
        _alightingStopIndex = stops.last.stopIndex;
      }
    });
  }

  double _computePrice(List<TripStop> stops) {
    // Prix complet si pas de tronçon sélectionné
    return widget.trip.price * _selectedSeats.length;
  }

  Future<void> _submit(List<TripStop> stops) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSeats.isEmpty) {
      setState(() => _errorMessage = 'Sélectionnez au moins une place');
      return;
    }
    final alighting = _alightingStopIndex ?? stops.last.stopIndex;
    if (alighting <= _boardingStopIndex) {
      setState(
        () => _errorMessage = 'Le débarquement doit être après l\'embarquement',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final selections = _selectedSeats
          .map(
            (seat) => {
              'passengerName': _nameControllers[seat]?.text.trim() ?? '',
              'seatNumber': seat,
            },
          )
          .toList();

      await ApiClient.instance.dio.post<void>(
        '/bookings/partner/offline-sale',
        data: {
          'tripId': widget.trip.id,
          'numberOfSeats': _selectedSeats.length,
          'selections': selections,
          'boardingStopIndex': _boardingStopIndex,
          'alightingStopIndex': alighting,
          'extraHoldBags': 0,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('—')
            ? e.toString().split('—').last.trim()
            : 'Erreur lors de la vente';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final occupiedAsync = ref.watch(_occupiedSeatsProvider(widget.trip.id));
    final stopsAsync = ref.watch(_tripStopsProvider(widget.trip.id));

    return stopsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.mobiliBlue),
      ),
      error: (e, _) => Center(
        child: Text(
          'Erreur stops : $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (stops) {
        final alighting = _alightingStopIndex ?? stops.last.stopIndex;
        final total = _computePrice(stops);

        return DraggableScrollableSheet(
          initialChildSize: 0.95,
          maxChildSize: 0.98,
          minChildSize: 0.6,
          expand: false,
          builder: (ctx, scrollCtrl) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vente directe',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mobiliBlueDeep,
                            ),
                          ),
                          Text(
                            '${widget.trip.departureCity} → ${widget.trip.arrivalCity}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.gray400,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.gray100),

              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Erreur
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Tronçon ──────────────────────────────────────────
                      const _SectionLabel(label: 'Tronçon'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StopDropdown(
                              label: 'Embarquement',
                              stops: stops,
                              value: _boardingStopIndex,
                              excludeIndex: null,
                              onChanged: (v) => setState(() {
                                _boardingStopIndex = v!;
                                if (_alightingStopIndex != null &&
                                    _alightingStopIndex! <= v!) {
                                  _alightingStopIndex = stops
                                      .where((s) => s.stopIndex > v!)
                                      .first
                                      .stopIndex;
                                }
                              }),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.gray400,
                              size: 18,
                            ),
                          ),
                          Expanded(
                            child: _StopDropdown(
                              label: 'Débarquement',
                              stops: stops
                                  .where(
                                    (s) => s.stopIndex > _boardingStopIndex,
                                  )
                                  .toList(),
                              value: alighting,
                              excludeIndex: _boardingStopIndex,
                              onChanged: (v) =>
                                  setState(() => _alightingStopIndex = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Carte des sièges ─────────────────────────────────
                      const _SectionLabel(label: 'Sélectionnez les places'),
                      const SizedBox(height: 12),
                      occupiedAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mobiliBlue,
                          ),
                        ),
                        error: (e, _) => Text(
                          'Erreur sièges : $e',
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        data: (occupied) => SeatMapWidget(
                          totalSeats: widget.trip.totalSeats,
                          occupied: occupied
                              .map((s) => int.tryParse(s) ?? 0)
                              .toList(),
                          selected: _selectedSeats,
                          onTap: (n) => _toggleSeat(n, stops),
                          vehicleType: widget.trip.vehicleType,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Noms passagers (un par siège) ────────────────────
                      if (_selectedSeats.isNotEmpty) ...[
                        const _SectionLabel(label: 'Noms des passagers'),
                        const SizedBox(height: 4),
                        const Text(
                          'Un nom par siège sélectionné',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gray400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._selectedSeats.map(
                          (seat) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextFormField(
                              controller: _nameControllers[seat],
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Obligatoire'
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Siège $seat — Nom passager',
                                prefixIcon: const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.gray400,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: AppColors.gray50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.gray200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.gray200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.mobiliBlue,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Total ────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.proGoldSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.proGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total à percevoir',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.proGold,
                                  ),
                                ),
                                Text(
                                  '${_selectedSeats.length} place(s) × ${NumberFormat('#,###').format(widget.trip.price)} F',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.proGold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              NumberFormat('#,###').format(total) + ' FCFA',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.proGold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Bouton ───────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _submit(stops),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mobiliBlue,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _selectedSeats.isEmpty
                                      ? 'Sélectionnez des places'
                                      : 'Confirmer ${_selectedSeats.length} place(s) — ${NumberFormat('#,###').format(total)} FCFA',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown stop
// ─────────────────────────────────────────────────────────────────────────────

class _StopDropdown extends StatelessWidget {
  const _StopDropdown({
    required this.label,
    required this.stops,
    required this.value,
    required this.onChanged,
    this.excludeIndex,
  });

  final String label;
  final List<TripStop> stops;
  final int value;
  final ValueChanged<int?> onChanged;
  final int? excludeIndex;

  @override
  Widget build(BuildContext context) {
    final validStops = stops.where((s) => s.stopIndex != excludeIndex).toList();
    final currentValue = validStops.any((s) => s.stopIndex == value)
        ? value
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.gray400),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: currentValue,
              isExpanded: true,
              hint: const Text(
                'Choisir',
                style: TextStyle(fontSize: 12, color: AppColors.gray400),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.gray400,
                size: 16,
              ),
              style: const TextStyle(
                color: AppColors.mobiliBlueDeep,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: validStops
                  .map(
                    (s) => DropdownMenuItem<int>(
                      value: s.stopIndex,
                      child: Text(s.cityLabel, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SeatMapWidget
// ─────────────────────────────────────────────────────────────────────────────

class SeatMapWidget extends StatelessWidget {
  const SeatMapWidget({
    super.key,
    required this.totalSeats,
    required this.occupied,
    required this.selected,
    required this.onTap,
    this.vehicleType,
  });

  final int totalSeats;
  final List<int> occupied;
  final List<String> selected;
  final ValueChanged<int> onTap;
  final String? vehicleType;

  bool get _is2x3 {
    final t = vehicleType?.toUpperCase() ?? '';
    return t.contains('70') ||
        t.contains('CLASSIQUE') ||
        t.contains('MASSA') ||
        t.contains('CAR');
  }

  int get _leftCols => 2;
  int get _rightCols => _is2x3 ? 3 : 2;
  int get _seatsPerRow => _leftCols + _rightCols;

  @override
  Widget build(BuildContext context) {
    final rows = (totalSeats / _seatsPerRow).ceil();
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 8),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicWidth(
              child: Column(
                children: [
                  _BusFront(leftCols: _leftCols, rightCols: _rightCols),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: Column(
                      children: List.generate(rows, (rowIdx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _BusRow(
                            rowIndex: rowIdx,
                            leftCols: _leftCols,
                            rightCols: _rightCols,
                            seatsPerRow: _seatsPerRow,
                            totalSeats: totalSeats,
                            occupied: occupied,
                            selected: selected,
                            onTap: onTap,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Legend(),
      ],
    );
  }
}

class _BusFront extends StatelessWidget {
  const _BusFront({required this.leftCols, required this.rightCols});
  final int leftCols;
  final int rightCols;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
      ),
    ),
    child: Row(
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Chauffeur',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Text(
              'Porte',
              style: TextStyle(
                color: AppColors.mobiliYellow.withValues(alpha: 0.9),
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 24,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.mobiliYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.mobiliYellow.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.mobiliYellow,
                size: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BusRow extends StatelessWidget {
  const _BusRow({
    required this.rowIndex,
    required this.leftCols,
    required this.rightCols,
    required this.seatsPerRow,
    required this.totalSeats,
    required this.occupied,
    required this.selected,
    required this.onTap,
  });

  final int rowIndex;
  final int leftCols;
  final int rightCols;
  final int seatsPerRow;
  final int totalSeats;
  final List<int> occupied;
  final List<String> selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final totalCols = leftCols + rightCols;
    final children = <Widget>[];

    children.add(
      SizedBox(
        width: 20,
        child: Text(
          '${rowIndex + 1}',
          style: const TextStyle(color: AppColors.gray300, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    );
    children.add(const SizedBox(width: 4));

    for (var col = 0; col < totalCols; col++) {
      if (col == leftCols) {
        children.add(const SizedBox(width: 16));
      } else if (col > 0 && col != leftCols) {
        children.add(const SizedBox(width: 5));
      }
      final seatNum = rowIndex * seatsPerRow + col + 1;
      final isLastCol = col == totalCols - 1;
      final isFirstCol = col == 0;
      final isWindow = isFirstCol || isLastCol;

      if (seatNum > totalSeats) {
        children.add(const SizedBox(width: 44, height: 44));
      } else {
        final isOccupied =
            occupied.contains(seatNum) || occupied.contains(seatNum.toString());
        final isSelected = selected.contains('$seatNum');
        children.add(
          _SeatCell(
            seatNum: seatNum,
            isOccupied: isOccupied,
            isSelected: isSelected,
            isWindow: isWindow,
            onTap: () => onTap(seatNum),
          ),
        );
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({
    required this.seatNum,
    required this.isOccupied,
    required this.isSelected,
    required this.isWindow,
    required this.onTap,
  });

  final int seatNum;
  final bool isOccupied;
  final bool isSelected;
  final bool isWindow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Border? border;

    if (isOccupied) {
      bg = const Color(0xFFFFEEEE);
      fg = AppColors.danger;
    } else if (isSelected) {
      bg = AppColors.mobiliYellow;
      fg = AppColors.mobiliBlueDeep;
      border = Border.all(color: AppColors.mobiliBlueDeep, width: 2);
    } else if (isWindow) {
      bg = const Color(0xFFEEF3FF);
      fg = AppColors.mobiliBlue;
      border = Border.all(
        color: AppColors.mobiliBlue.withValues(alpha: 0.25),
        width: 1,
      );
    } else {
      bg = AppColors.mobiliBlueFog;
      fg = AppColors.mobiliBlue;
    }

    return GestureDetector(
      onTap: isOccupied ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$seatNum',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            if (isWindow && !isOccupied && !isSelected)
              Positioned(
                top: 3,
                right: 3,
                child: Icon(
                  Icons.window_rounded,
                  size: 10,
                  color: AppColors.mobiliBlue.withValues(alpha: 0.45),
                ),
              ),
            if (isOccupied)
              Center(
                child: Icon(
                  Icons.cancel_rounded,
                  size: 20,
                  color: AppColors.danger.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _LegendItem(color: AppColors.mobiliBlueFog, label: 'Libre'),
      SizedBox(width: 12),
      _LegendItem(
        color: Color(0xFFEEF3FF),
        label: 'Fenêtre',
        hasBorder: true,
        icon: Icons.window_rounded,
      ),
      SizedBox(width: 12),
      _LegendItem(color: AppColors.mobiliYellow, label: 'Choisi'),
      SizedBox(width: 12),
      _LegendItem(
        color: Color(0xFFFFEEEE),
        label: 'Occupé',
        icon: Icons.cancel_rounded,
        iconColor: AppColors.danger,
      ),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.hasBorder = false,
    this.icon,
    this.iconColor,
  });

  final Color color;
  final String label;
  final bool hasBorder;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: hasBorder
              ? Border.all(color: AppColors.mobiliBlue.withValues(alpha: 0.3))
              : null,
        ),
        child: icon != null
            ? Icon(
                icon,
                size: 12,
                color: iconColor ?? AppColors.mobiliBlue.withValues(alpha: 0.5),
              )
            : null,
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(color: AppColors.gray500, fontSize: 10),
      ),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.mobiliBlueDeep,
    ),
  );
}
