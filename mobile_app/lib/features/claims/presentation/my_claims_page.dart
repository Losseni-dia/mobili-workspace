import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/mobili_app_bar.dart';
import '../../../shared/widgets/private_network_image.dart';
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
///
/// [highlightClaimId] : arrivée depuis une notification de clôture — scrolle et met en
/// évidence la réclamation concernée, même pattern que _highlightedBookingId dans
/// my_bookings_page.dart.
class MyClaimsPage extends ConsumerStatefulWidget {
  const MyClaimsPage({super.key, this.highlightClaimId});

  final int? highlightClaimId;

  @override
  ConsumerState<MyClaimsPage> createState() => _MyClaimsPageState();
}

class _MyClaimsPageState extends ConsumerState<MyClaimsPage> {
  int? _highlightedClaimId;
  final Map<int, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _highlightedClaimId = widget.highlightClaimId;
  }

  GlobalKey _keyFor(int claimId) => _cardKeys.putIfAbsent(claimId, () => GlobalKey());

  void _scrollToHighlighted() {
    final id = _highlightedClaimId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cardKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightedClaimId = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: AppColors.mobiliYellowPale,
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

          _scrollToHighlighted();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            itemBuilder: (context, i) {
              final claim = claims[i];
              return Padding(
                key: _keyFor(claim.id),
                padding: const EdgeInsets.only(bottom: 14),
                child: _ClaimCard(
                  claim: claim,
                  isHighlighted: claim.id == _highlightedClaimId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Ouvre une pièce jointe PDF via le partage système — `/media/private` exige un header
/// Authorization, donc pas de lien externe direct : on télécharge les octets avec le Dio
/// authentifié puis on délègue l'ouverture au OS (même pattern que support_page.dart).
Future<void> _openPdfAttachment(BuildContext context, Claim claim) async {
  if (claim.attachmentPath == null) return;
  try {
    final res = await ApiClient.instance.dio.get<List<int>>(
      '/media/private',
      queryParameters: {'rel': claim.attachmentPath},
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getTemporaryDirectory();
    final name = claim.attachmentOriginalName ?? 'piece-jointe.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(res.data!);
    await Share.shareXFiles([XFile(file.path)]);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible d\'ouvrir la pièce jointe : $e'),
          backgroundColor: AppColors.danger));
    }
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, this.isHighlighted = false});
  final Claim claim;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final reason = ClaimReasonType.fromApiValue(claim.reason);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? AppColors.mobiliBlue : AppColors.gray200,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.mobiliBlue.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
          if (claim.attachmentPath != null) ...[
            const SizedBox(height: 8),
            if (claim.isPdfAttachment)
              GestureDetector(
                onTap: () => _openPdfAttachment(context, claim),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          size: 16, color: AppColors.mobiliBlue),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(claim.attachmentOriginalName ?? 'Pièce jointe',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.mobiliBlueDeep)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: PrivateNetworkImage(relativePath: claim.attachmentPath!),
                ),
              ),
          ],
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
