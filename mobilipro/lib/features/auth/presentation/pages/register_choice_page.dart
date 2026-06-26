import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Choix du type d'inscription depuis le lien en bas de l'écran de connexion :
/// compagnie de transport (partenaire) ou conducteur covoiturage particulier.
/// Les deux flux demandent des informations différentes — voir
/// [RegisterCompanyPage] et [RegisterCarpoolChauffeurPage].
class RegisterChoicePage extends StatelessWidget {
  const RegisterChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text('Inscription', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vous voulez inscrire...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.mobiliBlueDeep,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Les informations demandées dépendent de votre choix.',
              style: TextStyle(color: AppColors.gray500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _ChoiceCard(
              icon: Icons.business_rounded,
              iconColor: AppColors.mobiliBlue,
              title: 'Une compagnie de transport',
              subtitle: 'Gérez vos trajets, vos gares et vos chauffeurs.',
              onTap: () => context.push('/register/company'),
            ),
            const SizedBox(height: 14),
            _ChoiceCard(
              icon: Icons.directions_car_filled_rounded,
              iconColor: AppColors.stationGreen,
              title: 'Conducteur covoiturage',
              subtitle: 'Proposez vos trajets avec votre propre véhicule.',
              onTap: () => context.push('/register/covoiturage'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.mobiliBlueDeep,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: AppColors.gray500, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }
}
