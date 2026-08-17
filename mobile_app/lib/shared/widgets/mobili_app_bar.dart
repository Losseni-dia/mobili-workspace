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

  // Toolbar standard : le logo (26px) tient sans excès d'espace dans la
  // hauteur normale de l'AppBar.
  double get _toolbarHeight => kToolbarHeight;

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
                  height: 26, fit: BoxFit.contain)
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
                Positioned.fill(
                  child: MobiliIconPattern(
                    color: iconColor,
                    size: const Size(392, 84),
                  ),
                ),
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
  const MobiliIconPattern({
    super.key,
    required this.color,
    this.cols = 7,
    this.rows = 3,
    this.iconSize = 22,
    this.alpha = 0.18,
    this.size,
  });

  final Color color;
  final int cols;
  final int rows;
  final double iconSize;
  final double alpha;

  /// Zone à couvrir. `null` = pleine page (MediaQuery, pour un fond de page
  /// complet) ; sinon une taille fixe (ex. la petite zone d'une AppBar, où
  /// caler sur la taille de l'écran entier donnerait des lignes trop
  /// espacées pour être visibles dans une barre compacte).
  final Size? size;

  static const _icons = [
    Icons.directions_bus_rounded,
    Icons.airport_shuttle_rounded,
    Icons.directions_car_rounded,
    Icons.two_wheeler_rounded,
    Icons.local_taxi_rounded,
    Icons.train_rounded,
  ];

  // Même technique que _TransportPattern (login_page.dart, déjà en prod et
  // fonctionnelle) : la grille se cale sur une taille connue à l'avance
  // (MediaQuery en plein écran, ou une taille fixe passée explicitement),
  // jamais sur les contraintes du parent — un LayoutBuilder derrière un
  // Positioned.fill dans un Stack imbriqué ne donnait pas le résultat
  // attendu en pratique.
  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? MediaQuery.of(context).size;
    final cellW = effectiveSize.width / cols;
    final cellH = effectiveSize.height / rows;
    final items = <Widget>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final icon = _icons[(r * cols + c) % _icons.length];
        final offset = (r % 2 == 0) ? 0.0 : cellW * 0.5;
        items.add(Positioned(
          left: c * cellW + offset - cellW * 0.1,
          top: r * cellH,
          child:
              Icon(icon, size: iconSize, color: color.withValues(alpha: alpha)),
        ));
      }
    }
    return Stack(children: items);
  }
}
