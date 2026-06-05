import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MobiliAppBar — AppBar bleu Mobili avec pattern icônes transport
// ─────────────────────────────────────────────────────────────────────────────

class MobiliAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MobiliAppBar({
    super.key,
    required this.title,
    this.backRoute,
    this.actions,
    this.bottom,
    this.showPattern = true,
  });

  final String title;
  final String? backRoute;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showPattern;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
 @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.mobiliBlue,
      foregroundColor: AppColors.white,
      elevation: 0,
      leading: backRoute != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.white, size: 20),
              onPressed: () => context.go(backRoute!),
            )
          : null,
      automaticallyImplyLeading: false,
      title: Text(title,
          style: AppTextStyles.titleLarge.copyWith(
            color: title == 'Mobili' ? AppColors.mobiliYellow : AppColors.white,
            fontWeight: FontWeight.w900,
            fontSize: title == 'Mobili' ? 28 : null,
            letterSpacing: title == 'Mobili' ? -0.5 : 0.5,
          )),
      actions: actions,
      bottom: bottom,
      flexibleSpace: showPattern
          ? Stack(
              children: [
                Container(color: AppColors.mobiliBlue),
                const Positioned.fill(child: _AppBarPattern()),
              ],
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pattern icônes transport
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarPattern extends StatelessWidget {
  const _AppBarPattern();

  static const _icons = [
    Icons.directions_bus_rounded,
    Icons.airport_shuttle_rounded,
    Icons.directions_car_rounded,
    Icons.two_wheeler_rounded,
    Icons.local_taxi_rounded,
    Icons.train_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    const cols = 7;
    const rows = 3;
    const cellW = 56.0;
    const cellH = 28.0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final icon = _icons[(r * cols + c) % _icons.length];
        final offset = (r % 2 == 0) ? 0.0 : cellW * 0.5;
        items.add(Positioned(
          left: c * cellW + offset,
          top: r * cellH.toDouble(),
          child: Icon(icon,
              size: 22, color: AppColors.white.withValues(alpha: 0.07)),
        ));
      }
    }
    return Stack(children: items);
  }
}
