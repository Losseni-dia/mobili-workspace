import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_colors.dart';

/// Bannière "Pas de connexion internet" affichée en haut de l'écran dès que
/// l'appareil perd toute connectivité réseau (AUDIT-MOBILI.md §3.4) — enveloppe
/// l'app entière via `MaterialApp.router(builder: ...)` dans main.dart pour rester
/// visible peu importe l'écran affiché, y compris login/register (hors shell
/// go_router). Purement informatif : ne bloque aucune interaction, se referme
/// automatiquement dès le retour du réseau.
class OfflineBannerOverlay extends ConsumerWidget {
  const OfflineBannerOverlay({super.key, required this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: isOnline ? const SizedBox(width: double.infinity) : const _OfflineBanner(),
        ),
        Expanded(child: child ?? const SizedBox.shrink()),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: AppColors.danger,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: AppColors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Pas de connexion internet',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
