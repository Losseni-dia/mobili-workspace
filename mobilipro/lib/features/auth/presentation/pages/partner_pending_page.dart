import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

class PartnerPendingPage extends ConsumerWidget {
  const PartnerPendingPage({super.key});

  Future<void> _openMail() async {
    final uri = Uri(scheme: 'mailto', path: 'support.mobili@gmail.com');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/2250465202023');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openCall() async {
    final uri = Uri(scheme: 'tel', path: '0465202023');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider.select((s) => s.value?.profile));
    final isRejected = profile?.isPartnerRejected ?? false;
    final reason = profile?.partnerRejectionReason;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Inscription société',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: isRejected
                      ? AppColors.dangerSoft
                      : AppColors.mobiliYellow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRejected
                      ? Icons.cancel_outlined
                      : Icons.hourglass_top_rounded,
                  color: isRejected
                      ? AppColors.danger
                      : AppColors.proGold,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isRejected
                  ? 'Votre dossier a été rejeté'
                  : 'Votre dossier est en cours de vérification',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.mobiliBlueDeep,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isRejected
                  ? 'Votre société n\'a pas pu être validée par notre équipe. Consultez le motif ci-dessous et corrigez votre dossier.'
                  : 'Nous vérifions les documents fournis à l\'inscription. Cette étape prend généralement moins de 24h (jours ouvrables).',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.gray500,
                height: 1.5,
              ),
            ),
         if (isRejected && reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motif du rejet',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reason,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isRejected) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/partner/resubmit'),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text(
                    'Corriger et soumettre à nouveau',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliYellow,
                    foregroundColor: AppColors.mobiliBlueDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gray200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compte non activé après 24h (jour ouvrable) ?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mobiliBlueDeep,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Contactez notre équipe support :',
                    style: TextStyle(color: AppColors.gray500, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: 'support.mobili@gmail.com',
                    onTap: _openMail,
                  ),
                  const SizedBox(height: 8),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: '04 65 20 20 23',
                    onTap: _openCall,
                  ),
                  const SizedBox(height: 8),
                  _ContactRow(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp : 04 65 20 20 23',
                    onTap: _openWhatsApp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mobiliBlue),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mobiliBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
