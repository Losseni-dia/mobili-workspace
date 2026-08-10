import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/mobili_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/claim_service.dart';
import '../domain/models/claim.dart';
import '../domain/models/claim_reason.dart';
import 'claim_status_timeline.dart';

final _myClaimsProvider = FutureProvider.autoDispose.family<List<Claim>, int>((ref, userId) async {
  return ClaimService().getMyClaims(userId);
});

/// Historique des réclamations du passager, avec la timeline de statut pour chacune —
/// réutilise GET /claims/mine/{userId}, déjà exposé par ClaimService (Flutter) depuis la
/// soumission du formulaire, aucun nouvel appel réseau à construire.
class MyClaimsPage extends ConsumerWidget {
  const MyClaimsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).valueOrNull?.profile;

    if (profile == null) {
      return Scaffold(
        appBar: const MobiliAppBar(title: 'Mes réclamations', showBackButton: true),
        body: Center(
          child: Text('Connectez-vous pour voir vos réclamations',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray500),
              textAlign: TextAlign.center),
        ),
      );
    }

    final claimsAsync = ref.watch(_myClaimsProvider(profile.id));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: const MobiliAppBar(title: 'Mes réclamations', showBackButton: true),
      body: claimsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $e',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray500),
                textAlign: TextAlign.center),
          ),
        ),
        data: (claims) {
          if (claims.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.mobiliBlueFog,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.report_problem_outlined,
                          color: AppColors.mobiliBlue, size: 36),
                    ),
                    const SizedBox(height: 14),
                    Text('Aucune réclamation envoyée',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.mobiliBlueDeep)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ClaimCard(claim: claims[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});
  final Claim claim;

  @override
  Widget build(BuildContext context) {
    final reason = ClaimReasonType.fromApiValue(claim.reason);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(reason.icon, size: 18, color: AppColors.mobiliBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(reason.label,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700, color: AppColors.mobiliBlueDeep)),
              ),
            ],
          ),
          if (claim.booking != null) ...[
            const SizedBox(height: 4),
            Text(
              '${claim.booking!.route} · Réf. ${claim.booking!.reference}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray500),
            ),
          ],
          const SizedBox(height: 4),
          Text(claim.message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray600)),
          const SizedBox(height: 16),
          ClaimStatusTimeline(
            status: claim.status,
            createdAt: claim.createdAt,
            resolvedAt: claim.resolvedAt,
            resolutionMessage: claim.resolutionMessage,
          ),
        ],
      ),
    );
  }
}
