import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).valueOrNull?.profile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final roleLabel = _roleLabel(profile.roles);
    final roleColor = _roleColor(profile.roles);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.mobiliBlue,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.mobiliYellow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.3),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          profile.firstname.isNotEmpty
                              ? profile.firstname[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppColors.mobiliBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: roleColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Infos compte ─────────────────────────────────
                  _SectionTitle(title: 'Informations du compte'),
                  const SizedBox(height: 8),
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Nom complet',
                        value: profile.fullName,
                      ),
                      const Divider(height: 1, color: AppColors.gray100),
                      _InfoRow(
                        icon: Icons.alternate_email_rounded,
                        label: 'Identifiant',
                        value: '@${profile.login}',
                      ),
                      const Divider(height: 1, color: AppColors.gray100),
                     _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: profile.email ?? 'Non renseigné',
                      ),
                      const Divider(height: 1, color: AppColors.gray100),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Téléphone',
                        value: profile.phone ?? 'Non renseigné',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Rôles ────────────────────────────────────────
                  _SectionTitle(title: 'Rôles & accès'),
                  const SizedBox(height: 8),
                  _InfoCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.roles
                              .map(
                                (r) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.mobiliBlueFog,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.mobiliBlue.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    r,
                                    style: const TextStyle(
                                      color: AppColors.mobiliBlue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Statut compte ────────────────────────────────
                  _SectionTitle(title: 'Statut'),
                  const SizedBox(height: 8),
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: profile.enabled
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        label: 'Compte',
                        value: profile.enabled ? 'Actif' : 'Désactivé',
                        valueColor: profile.enabled
                            ? AppColors.stationGreen
                            : AppColors.danger,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Déconnexion ──────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Se déconnecter ?'),
                            content: const Text(
                              'Voulez-vous vraiment vous déconnecter de MobiliPro ?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Annuler'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Se déconnecter',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(authProvider.notifier).logout();
                        }
                      },
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.danger,
                      ),
                      label: const Text('Se déconnecter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Version app
                  Center(
                    child: Text(
                      'MobiliPro v1.0.0',
                      style: TextStyle(color: AppColors.gray400, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(List<String> roles) {
    if (roles.contains('ADMIN')) return 'SUPER ADMIN';
    if (roles.contains('PARTNER')) return 'PARTENAIRE';
    if (roles.contains('GARE')) return 'GARE';
    if (roles.contains('CHAUFFEUR')) return 'CHAUFFEUR';
    if (roles.contains('COVOITURAGE')) return 'CONDUCTEUR';
    return 'UTILISATEUR';
  }

  Color _roleColor(List<String> roles) {
    if (roles.contains('ADMIN')) return AppColors.proGold;
    if (roles.contains('PARTNER')) return AppColors.mobiliYellow;
    if (roles.contains('GARE')) return AppColors.stationGreen;
    if (roles.contains('CHAUFFEUR')) return AppColors.mobiliBlue;
    if (roles.contains('COVOITURAGE')) return AppColors.warning;
    return AppColors.gray400;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.gray500,
      letterSpacing: 0.5,
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gray200),
      boxShadow: AppColors.shadowSm,
    ),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mobiliBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? AppColors.gray700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
