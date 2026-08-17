import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MobiliAppBar — AppBar bleu Mobili avec pattern icônes transport
// Cas spécial title == 'Mobili' (page d'accueil) : fond jaune Mobili + logo
// écrit (ecrito_bleu.png, wordmark bleu) au lieu du texte — aligné sur le
// header web (fond clair, logo "MOBILI" bleu).
// ─────────────────────────────────────────────────────────────────────────────

class MobiliAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MobiliAppBar({
    super.key,
    required this.title,
    this.backRoute,
    this.showBackButton = false,
    this.actions,
    this.bottom,
    this.showPattern = true,
    this.titleFontSize,
    this.subtitle,
  });

  final String title;
  final String? backRoute;
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showPattern;
  final double? titleFontSize;

  /// Petit texte secondaire sous le titre (ex. "Support Mobili"). Le titre
  /// passe alors en une seule ligne tronquée pour laisser la place.
  final String? subtitle;

  bool get _isHome => title == 'Mobili';

  // Toolbar ajustée à la taille du logo écrit (asset recadré à son contenu
  // réel, voir ecrito_bleu.png — plus de marge transparente cachée) : juste
  // assez de hauteur pour l'afficher sans excès d'espace vide autour.
  double get _toolbarHeight => _isHome ? 148 : kToolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(
        _toolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final bgColor = _isHome ? AppColors.mobiliYellow : AppColors.mobiliBlue;
    final iconColor = _isHome ? AppColors.mobiliBlueDeep : AppColors.white;

    return AppBar(
      backgroundColor: bgColor,
      foregroundColor: iconColor,
      elevation: 0,
      toolbarHeight: _toolbarHeight,
      leading: backRoute != null
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: iconColor, size: 20),
              onPressed: () => context.go(backRoute!),
            )
          : showBackButton
              ? IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: iconColor, size: 20),
                  onPressed: () => context.pop(),
                )
              : null,
      automaticallyImplyLeading: false,
      title: subtitle == null
          ? (_isHome
              ? Image.asset('assets/icons/ecrito_bleu.png',
                  height: 128, fit: BoxFit.contain)
              : Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: titleFontSize,
                    letterSpacing: 0.5,
                  )))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.w700,
                      fontSize: titleFontSize ?? 16,
                    )),
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: _isHome
                          ? AppColors.mobiliBlueDeep.withValues(alpha: 0.8)
                          : const Color(0xCCFFFFFF),
                    )),
              ],
            ),
      actions: actions,
      bottom: bottom,
      flexibleSpace: showPattern
          ? Stack(
              children: [
                Container(color: bgColor),
                Positioned.fill(child: MobiliIconPattern(color: iconColor)),
              ],
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pattern icônes transport — public : réutilisé tel quel en fond de page
// (ex. trips_list_page, fond jaune de l'accueil) pour garder exactement le
// même motif que celui de l'AppBar, jamais une resémantisation approchante.
// ─────────────────────────────────────────────────────────────────────────────

class MobiliIconPattern extends StatelessWidget {
  const MobiliIconPattern({super.key, required this.color});

  final Color color;

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
          child: Icon(icon, size: 22, color: color.withValues(alpha: 0.18)),
        ));
      }
    }
    return Stack(children: items);
  }
}
