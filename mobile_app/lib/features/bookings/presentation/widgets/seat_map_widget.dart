import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Plan de bus réaliste — 2+2 ou 2+3 selon le type de véhicule
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
        // ── Carrosserie du bus ───────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 8)
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicWidth(
              child: Column(
                children: [
                  // ── Avant bus ──────────────────────
                  _BusFront(leftCols: _leftCols, rightCols: _rightCols),

                  // ── Sièges ─────────────────────────
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

        // ── Légende ──────────────────────────────────
        _Legend(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avant du bus
// ─────────────────────────────────────────────────────────────────────────────

class _BusFront extends StatelessWidget {
  const _BusFront({required this.leftCols, required this.rightCols});
  final int leftCols;
  final int rightCols;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
        ),
      ),
      child: Row(
        children: [
          // Chauffeur
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.6),
                      width: 1.5),
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.white, size: 16),
              ),
              const SizedBox(width: 6),
              Text('Chauffeur',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontSize: 10,
                  )),
            ],
          ),
          const Spacer(),
          // Porte
          Row(
            children: [
              Text('Porte',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.mobiliYellow.withValues(alpha: 0.9),
                    fontSize: 10,
                  )),
              const SizedBox(width: 6),
              Container(
                width: 24,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.mobiliYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppColors.mobiliYellow.withValues(alpha: 0.5),
                      width: 1.5),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.mobiliYellow, size: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rangée de sièges
// ─────────────────────────────────────────────────────────────────────────────

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

    // Numéro rangée
    children.add(SizedBox(
      width: 20,
      child: Text('${rowIndex + 1}',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.gray300,
            fontSize: 10,
          ),
          textAlign: TextAlign.center),
    ));
    children.add(const SizedBox(width: 4));

    for (var col = 0; col < totalCols; col++) {
      // Allée centrale
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

        children.add(_SeatCell(
          seatNum: seatNum,
          isOccupied: isOccupied,
          isSelected: isSelected,
          isWindow: isWindow,
          onTap: () => onTap(seatNum),
        ));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Siège individuel
// ─────────────────────────────────────────────────────────────────────────────

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
          color: AppColors.mobiliBlue.withValues(alpha: 0.25), width: 1);
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
              child: Text('$seatNum',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  )),
            ),
            // Icône fenêtre
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
            // Croix si occupé
            if (isOccupied)
              Center(
                child: Icon(Icons.cancel_rounded,
                    size: 20, color: AppColors.danger.withValues(alpha: 0.6)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Légende
// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(
          color: AppColors.mobiliBlueFog,
          label: 'Libre',
        ),
        SizedBox(width: 12),
        _LegendItem(
          color: Color(0xFFEEF3FF),
          label: 'Fenêtre',
          hasBorder: true,
          icon: Icons.window_rounded,
        ),
        SizedBox(width: 12),
        _LegendItem(
          color: AppColors.mobiliYellow,
          label: 'Choisi',
        ),
        SizedBox(width: 12),
       _LegendItem(
          color: const Color(0xFFFFEEEE),
          label: 'Occupé',
          icon: Icons.cancel_rounded,
          iconColor: AppColors.danger,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.hasBorder = false,
    this.icon,
    this.iconColor,
    this.crossOut = false,
  });

  final Color color;
  final String label;
  final bool hasBorder;
  final IconData? icon;
  final Color? iconColor;
  final bool crossOut;

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
                  ? Border.all(
                      color: AppColors.mobiliBlue.withValues(alpha: 0.3))
                  : null,
            ),
            child: icon != null
                ? Icon(icon,
                    size: 12,
                    color: iconColor ??
                        AppColors.mobiliBlue.withValues(alpha: 0.5))
                : null,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.gray500,
                fontSize: 10,
              )),
        ],
      );
}
