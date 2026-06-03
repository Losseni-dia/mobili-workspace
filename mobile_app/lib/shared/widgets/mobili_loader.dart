import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Indicateurs de chargement Mobili
///
/// Contraintes low-end :
///   - Pas de package shimmer externe (poids) — animation opacity native
///   - CircularProgressIndicator Flutter (hardware-accelerated)
///   - Pas d'AnimatedBuilder complexe
///
/// Composants :
///   [MobiliLoader]         — spinner centré (page / section)
///   [MobiliInlineLoader]   — row compact (liste, chargement partiel)
///   [MobiliOverlayLoader]  — overlay bloquant (paiement, soumission)
///   [MobiliSkeletonBox]    — boîte placeholder pulsée
///   [MobiliTripCardSkeleton] — skeleton carte trajet
///   [MobiliSkeletonList]   — liste de skeletons

// ─────────────────────────────────────────────────────────────────────────────
// SPINNER CENTRÉ
// ─────────────────────────────────────────────────────────────────────────────

/// Spinner principal — centré dans sa section / page
///
/// ```dart
/// if (state.isLoading) return const MobiliLoader();
/// if (state.isLoading) return const MobiliLoader(message: 'Chargement…');
/// ```
class MobiliLoader extends StatelessWidget {
  const MobiliLoader({
    super.key,
    this.message,
    this.size = 36.0,
    this.strokeWidth = 3.0,
    this.color,
    this.padding = const EdgeInsets.all(32),
  });

  final String? message;
  final double size;
  final double strokeWidth;

  /// null → couleur thème (bleu light, jaune dark)
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color c =
        color ?? (isDark ? AppColors.mobiliYellow : AppColors.mobiliBlue);
    final Color track = isDark
        ? const Color(0xFF1A2E6B)
        : AppColors.mobiliBlueFog;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: strokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(c),
                backgroundColor: track,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkOnSurfaceVar
                      : AppColors.gray500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE LOADER
// ─────────────────────────────────────────────────────────────────────────────

/// Row de chargement compact — listes, vérification paiement, refresh
///
/// ```dart
/// MobiliInlineLoader(label: 'Vérification en cours…')
/// ```
class MobiliInlineLoader extends StatelessWidget {
  const MobiliInlineLoader({
    super.key,
    this.label,
    this.size = 18.0,
    this.color,
    this.padding =
        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  });

  final String? label;
  final double size;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color c =
        color ?? (isDark ? AppColors.mobiliYellow : AppColors.mobiliBlue);
    final Color track = isDark
        ? const Color(0xFF1A2E6B)
        : AppColors.mobiliBlueFog;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(c),
              backgroundColor: track,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 10),
            Text(
              label!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.darkOnSurfaceVar
                    : AppColors.gray500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY LOADER — BLOQUANT (paiement, soumission critique)
// ─────────────────────────────────────────────────────────────────────────────

/// Overlay bloquant plein écran — à wrapper dans un [Stack]
///
/// ```dart
/// Stack(
///   children: [
///     _buildContent(),
///     if (_isProcessing)
///       const MobiliOverlayLoader(message: 'Traitement du paiement…'),
///   ],
/// )
/// ```
class MobiliOverlayLoader extends StatelessWidget {
  const MobiliOverlayLoader({
    super.key,
    this.message = 'Chargement…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg =
        isDark ? AppColors.darkSurfaceRaised : AppColors.white;
    final Color c =
        isDark ? AppColors.mobiliYellow : AppColors.mobiliBlue;
    final Color track = isDark
        ? const Color(0xFF1A2E6B)
        : AppColors.mobiliBlueFog;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.shadowLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(c),
                  backgroundColor: track,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium.copyWith(
                  color: isDark
                      ? AppColors.darkOnSurface
                      : AppColors.mobiliBlueDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON BOX — placeholder pulsé
// ─────────────────────────────────────────────────────────────────────────────

/// Boîte skeleton animée (pulse opacity — pas de shimmer package)
/// Conforme low-end : une seule animation, réutilisée via le widget tree.
class MobiliSkeletonBox extends StatefulWidget {
  const MobiliSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<MobiliSkeletonBox> createState() => _MobiliSkeletonBoxState();
}

class _MobiliSkeletonBoxState extends State<MobiliSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.75)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color base =
        isDark ? AppColors.darkSurfaceRaised : AppColors.gray100;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON CARTE TRAJET
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton d'une carte de trajet en liste
class MobiliTripCardSkeleton extends StatelessWidget {
  const MobiliTripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar compagnie
          const MobiliSkeletonBox(width: 46, height: 46, borderRadius: 12),
          const SizedBox(width: 12),
          // Texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MobiliSkeletonBox(
                    width: w * 0.45, height: 16, borderRadius: 6),
                const SizedBox(height: 8),
                MobiliSkeletonBox(
                    width: w * 0.30, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Prix
          const MobiliSkeletonBox(width: 60, height: 22, borderRadius: 11),
        ],
      ),
    );
  }
}

/// Skeleton d'une réservation / ticket
class MobiliBookingCardSkeleton extends StatelessWidget {
  const MobiliBookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MobiliSkeletonBox(width: w * 0.40, height: 18, borderRadius: 6),
              const MobiliSkeletonBox(width: 70, height: 22, borderRadius: 11),
            ],
          ),
          const SizedBox(height: 10),
          MobiliSkeletonBox(width: w * 0.55, height: 14, borderRadius: 6),
          const SizedBox(height: 6),
          MobiliSkeletonBox(width: w * 0.35, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON LIST — pile de skeletons
// ─────────────────────────────────────────────────────────────────────────────

/// Liste paginée de skeletons — pré-remplissage avant données réelles
///
/// ```dart
/// if (state.isLoading)
///   return const MobiliSkeletonList(count: 6);
/// ```
class MobiliSkeletonList extends StatelessWidget {
  const MobiliSkeletonList({
    super.key,
    this.count = 5,
    this.itemBuilder,
    this.separator = true,
  });

  final int count;
  final Widget Function(BuildContext context, int index)? itemBuilder;
  final bool separator;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color div =
        isDark ? AppColors.darkOutline : AppColors.gray100;

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: count,
      separatorBuilder: (_, __) =>
          separator ? Divider(height: 1, color: div) : const SizedBox(),
      itemBuilder: itemBuilder ?? (ctx, _) => const MobiliTripCardSkeleton(),
    );
  }
}
