import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'mobili_button.dart';

/// Types d'états vides prédéfinis pour Mobili
enum MobiliEmptyType {
  trips,         // Aucun trajet trouvé
  bookings,      // Aucune réservation
  tickets,       // Aucun ticket
  notifications, // Inbox vide
  search,        // Aucun résultat de recherche
  offline,       // Pas de connexion Internet
  messages,      // Canal messages vide
  generic,       // Fallback
}

/// Widget état vide Mobili — page ou section sans contenu
///
/// ```dart
/// // Simple
/// if (trips.isEmpty)
///   return const EmptyStateWidget(type: MobiliEmptyType.trips);
///
/// // Avec CTA
/// EmptyStateWidget(
///   type: MobiliEmptyType.bookings,
///   actionLabel: 'Rechercher un trajet',
///   onAction: () => context.go('/trips'),
/// )
///
/// // Compact (dans une liste)
/// EmptyStateWidget(
///   type: MobiliEmptyType.notifications,
///   compact: true,
/// )
///
/// // Personnalisé
/// EmptyStateWidget.custom(
///   icon: Icons.construction_rounded,
///   title: 'Section en construction',
///   subtitle: 'Disponible prochainement.',
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.type,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  })  : _icon = null,
        _title = null,
        _subtitle = null;

  const EmptyStateWidget.custom({
    super.key,
    required IconData icon,
    required String title,
    String? subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  })  : type = MobiliEmptyType.generic,
        _icon = icon,
        _title = title,
        _subtitle = subtitle;

  final MobiliEmptyType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  final IconData? _icon;
  final String? _title;
  final String? _subtitle;

  // ── Config par type ───────────────────────────────────────────────────
  _EmptyCfg _cfg() {
    if (_icon != null) {
      return _EmptyCfg(
        icon: _icon!,
        title: _title ?? 'Aucun contenu',
        subtitle: _subtitle,
        accent: AppColors.mobiliBlue,
        accentBg: AppColors.mobiliBlueFog,
      );
    }
    return switch (type) {
      MobiliEmptyType.trips => const _EmptyCfg(
          icon: Icons.directions_bus_outlined,
          title: 'Aucun trajet disponible',
          subtitle:
              'Aucun trajet ne correspond à votre recherche pour le moment.',
          accent: AppColors.mobiliBlue,
          accentBg: AppColors.mobiliBlueFog,
        ),
      MobiliEmptyType.bookings => const _EmptyCfg(
          icon: Icons.luggage_outlined,
          title: 'Aucune réservation',
          subtitle:
              'Vos réservations apparaîtront ici après votre premier achat.',
          accent: AppColors.mobiliYellowDark,
          accentBg: Color(0xFFFFF8D0),
        ),
      MobiliEmptyType.tickets => const _EmptyCfg(
          icon: Icons.confirmation_number_outlined,
          title: 'Aucun ticket',
          subtitle: 'Vos billets électroniques apparaîtront ici.',
          accent: AppColors.success,
          accentBg: AppColors.successSoft,
        ),
      MobiliEmptyType.notifications => const _EmptyCfg(
          icon: Icons.notifications_none_rounded,
          title: 'Aucune notification',
          subtitle: 'Vous êtes à jour ! Les alertes s\'afficheront ici.',
          accent: AppColors.mobiliBlue,
          accentBg: AppColors.mobiliBlueFog,
        ),
      MobiliEmptyType.search => const _EmptyCfg(
          icon: Icons.search_off_rounded,
          title: 'Aucun résultat',
          subtitle:
              'Essayez avec d\'autres mots-clés, dates ou villes de départ.',
          accent: AppColors.mobiliBlue,
          accentBg: AppColors.mobiliBlueFog,
        ),
      MobiliEmptyType.offline => const _EmptyCfg(
          icon: Icons.wifi_off_rounded,
          title: 'Hors connexion',
          subtitle:
              'Vérifiez votre connexion Internet et réessayez.',
          accent: AppColors.warning,
          accentBg: AppColors.warningSoft,
        ),
      MobiliEmptyType.messages => const _EmptyCfg(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Aucun message',
          subtitle: 'Le canal de ce trajet est vide.',
          accent: AppColors.mobiliBlue,
          accentBg: AppColors.mobiliBlueFog,
        ),
      MobiliEmptyType.generic => const _EmptyCfg(
          icon: Icons.inbox_outlined,
          title: 'Rien ici',
          subtitle: null,
          accent: AppColors.mobiliBlue,
          accentBg: AppColors.mobiliBlueFog,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = _cfg();

    final Color accent =
        isDark ? _darkAccent(cfg.accent) : cfg.accent;
    final Color accentBg =
        isDark ? _darkAccentBg(cfg.accent) : cfg.accentBg;
    final Color titleColor =
        isDark ? AppColors.darkOnSurface : AppColors.mobiliBlueDeep;
    final Color subColor =
        isDark ? AppColors.darkOnSurfaceVar : AppColors.gray600;

    if (compact) {
      return _CompactEmpty(
        cfg: cfg,
        accent: accent,
        accentBg: accentBg,
        titleColor: titleColor,
        subColor: subColor,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration
            _Illustration(
              icon: cfg.icon,
              accent: accent,
              accentBg: accentBg,
            ),
            const SizedBox(height: 24),

            // Titre — Plus Jakarta Sans 900
            Text(
              cfg.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMedium.copyWith(color: titleColor),
            ),

            // Sous-titre
            if (cfg.subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                cfg.subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(color: subColor),
              ),
            ],

            // Action — bouton primaire CTA gold
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 32),
              MobiliButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
                size: MobiliButtonSize.medium,
                showShadow: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Dark mode — atténue les accents trop vifs
  Color _darkAccent(Color light) {
    if (light == AppColors.mobiliBlue) return AppColors.mobiliYellowSoft;
    if (light == AppColors.mobiliYellowDark) return AppColors.mobiliYellow;
    if (light == AppColors.success) return AppColors.stationGreenSoft;
    if (light == AppColors.warning) return AppColors.mobiliYellowSoft;
    return AppColors.mobiliBlueSoft;
  }

  Color _darkAccentBg(Color light) {
    if (light == AppColors.mobiliBlue) return const Color(0xFF0F1E50);
    if (light == AppColors.mobiliYellowDark) return const Color(0xFF2A2000);
    if (light == AppColors.success) return const Color(0xFF052E0F);
    if (light == AppColors.warning) return const Color(0xFF2A2000);
    return AppColors.darkSurfaceRaised;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ILLUSTRATION ICÔNE
// ─────────────────────────────────────────────────────────────────────────────
class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.icon,
    required this.accent,
    required this.accentBg,
  });
  final IconData icon;
  final Color accent, accentBg;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo externe
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentBg.withValues(alpha: 0.5),
          ),
        ),
        // Cercle principal avec bordure signature
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentBg,
            border: Border.all(
              color: accent.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(icon, size: 42, color: accent),
        ),
        // Accent dot — signature Mobili (coin supérieur droit)
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERSION COMPACTE
// ─────────────────────────────────────────────────────────────────────────────
class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({
    required this.cfg,
    required this.accent,
    required this.accentBg,
    required this.titleColor,
    required this.subColor,
    this.actionLabel,
    this.onAction,
  });
  final _EmptyCfg cfg;
  final Color accent, accentBg, titleColor, subColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentBg,
              border: Border.all(
                  color: accent.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Icon(cfg.icon, size: 22, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cfg.title,
                  style: AppTextStyles.titleSmall.copyWith(color: titleColor),
                ),
                if (cfg.subtitle != null)
                  Text(
                    cfg.subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(color: subColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: AppTextStyles.buttonSmall.copyWith(color: accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyCfg {
  const _EmptyCfg({
    required this.icon,
    required this.title,
    required this.accent,
    required this.accentBg,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final Color accentBg;
}
