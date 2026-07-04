import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobili/features/support/presentation/pages/support_page.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../auth/domain/models/profile_dto.dart';
import '../../../auth/providers/auth_provider.dart';

/// Point d'entrée unique de l'espace covoiturage conducteur. Redirige vers
/// l'écran adapté au statut KYC de l'utilisateur courant — voir
/// [ProfileDto.covoiturageKycStatus].
class CovoiturageEntryPage extends ConsumerStatefulWidget {
  const CovoiturageEntryPage({super.key});

  @override
  ConsumerState<CovoiturageEntryPage> createState() =>
      _CovoiturageEntryPageState();
}

class _CovoiturageEntryPageState extends ConsumerState<CovoiturageEntryPage> {
  @override
  void initState() {
    super.initState();
    // Le statut KYC (ex: validation admin) a pu changer côté serveur depuis
    // le dernier login — on re-fetch le profil à chaque entrée sur cet
    // espace pour ne pas afficher un statut périmé sans obliger l'utilisateur
    // à se déconnecter/reconnecter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    if (profile == null || !profile.hasCovoiturageProfile) {
      return _IntroScreen(
        // Pas connecté → inscription complète (crée un nouveau compte).
        // Déjà connecté → candidature rattachée au compte existant.
        onStart: () => context.push(
          profile == null ? '/covoiturage/register' : '/covoiturage/apply',
        ),
      );
    }

    if (profile.covoiturageKycApproved) {
      return const _DriverDashboardRedirect();
    }

    return _KycStatusScreen(profile: profile);
  }
}

class _DriverDashboardRedirect extends StatelessWidget {
  const _DriverDashboardRedirect();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/covoiturage/trips');
    });
    return const _CovoiturageScaffold(
      child: Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Écran d'introduction (jamais inscrit)
// ─────────────────────────────────────────────────────────────────────────────

class _IntroScreen extends StatelessWidget {
  const _IntroScreen({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _CovoiturageScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.mobiliYellow,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.directions_car_filled_rounded,
                  color: AppColors.mobiliBlueDeep, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Devenez conducteur covoiturage',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 10),
            Text(
              'Proposez vos trajets avec votre propre véhicule et partagez '
              'les frais avec d\'autres voyageurs.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.white.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RequirementRow(
                    icon: Icons.badge_outlined,
                    text: 'Pièce d\'identité valide (recto/verso)',
                  ),
                  SizedBox(height: 14),
                  _RequirementRow(
                    icon: Icons.face_retouching_natural_rounded,
                    text: 'Photo de vous (vérification du conducteur)',
                  ),
                  SizedBox(height: 14),
                  _RequirementRow(
                    icon: Icons.directions_car_rounded,
                    text: 'Photo et infos de votre véhicule',
                  ),
                  SizedBox(height: 14),
                  _RequirementRow(
                    icon: Icons.verified_user_outlined,
                    text: 'Validation par un administrateur Mobili',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            MobiliButton(
              label: 'Commencer l\'inscription',
              icon: Icons.arrow_forward_rounded,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.mobiliBlueFog,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: AppColors.mobiliBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.mobiliBlueDeep)),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Écran statut KYC (PENDING / REJECTED / EXPIRED)
// ─────────────────────────────────────────────────────────────────────────────

class _KycStatusScreen extends StatelessWidget {
  const _KycStatusScreen({required this.profile});
  final ProfileDto profile;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, body) = switch (profile.covoiturageKycStatus) {
      'PENDING' => (
          Icons.hourglass_top_rounded,
          AppColors.warning,
          'Dossier en cours de validation',
          'Votre demande a été envoyée. Un administrateur Mobili doit '
              'valider le avant que vous puissiez publier des '
              'trajets. Vous recevrez une notification dès que c\'est fait.',
        ),
      'REJECTED' => (
          Icons.cancel_outlined,
          AppColors.danger,
          'Dossier refusé',
          'Votre dossier conducteur a été refusé. Vous pouvez soumettre un '
              'nouveau dossier, ou contacter le support pour en connaître la '
              'raison.',
        ),                 
      'EXPIRED' => (
          Icons.warning_amber_rounded,
          AppColors.danger,
          'Pièce d\'identité expirée',
          'La date de validité de votre pièce d\'identité est dépassée. '
              'Soumettez un nouveau dossier avec une CNI à jour pour '
              'reprendre la publication de trajets.',
        ),
    'NONE' => (
          Icons.info_outline_rounded,
          AppColors.mobiliBlue,
          'Aucun dossier soumis',
          'Vous n\'avez pas encore soumis de dossier conducteur covoiturage.',
        ),
      _ => (
          Icons.info_outline_rounded,
          AppColors.gray400,
          'Dossier en traitement',
          'Contactez le support Mobili pour plus d\'informations sur votre '
              'dossier conducteur.',
        ),
    };

    return _CovoiturageScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 44),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 12),
            Text(body,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.white.withValues(alpha: 0.8))),
            const SizedBox(height: 28),
           if (profile.covoiturageKycRejected ||
                profile.covoiturageKycExpired ||
                profile.covoiturageKycStatus == 'NONE') ...[
              MobiliButton(
                label: profile.covoiturageKycStatus == 'NONE'
                    ? 'Soumettre mon dossier'
                    : 'Soumettre un nouveau dossier',
                icon: profile.covoiturageKycStatus == 'NONE'
                    ? Icons.arrow_forward_rounded
                    : Icons.refresh_rounded,
                onPressed: () => context.push('/covoiturage/apply'),
              ),
              const SizedBox(height: 12),
            ],
           // Le fond de cet écran est toujours sombre (gradientHeaderDark),
            // quel que soit le thème de l'app — on force donc le contexte de
            // luminosité à dark pour ce bouton .outlined, sinon il choisit les
            // couleurs "mode clair" (bleu sur bleu = invisible) sur ce fond.
            _WhiteOutlinedButton(
              label: 'Contacter le support',
              icon: Icons.support_agent_rounded,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scaffold commun
// ─────────────────────────────────────────────────────────────────────────────

class _CovoiturageScaffold extends StatelessWidget {
  const _CovoiturageScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppColors.gradientHeaderDark)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.white, size: 20),
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/profile'),
                      ),
                      Expanded(
                        child: Text('Espace covoiturage',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ],
                  ),
                ),
                Expanded(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton bordure blanche — spécifique aux écrans à fond sombre
// (MobiliButton.outlined choisit entre jaune/bleu selon le thème global,
// jamais blanc, donc on ne peut pas l'utiliser tel quel ici).
// ─────────────────────────────────────────────────────────────────────────────

class _WhiteOutlinedButton extends StatelessWidget {
  const _WhiteOutlinedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.white.withValues(alpha: 0.15),
          highlightColor: AppColors.white.withValues(alpha: 0.08),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.white, width: 2),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: AppColors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTextStyles.buttonPrimary.copyWith(
                      color: AppColors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
