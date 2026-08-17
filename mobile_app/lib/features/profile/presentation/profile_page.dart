import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/bookings/data/booking_service.dart';
import '../../../features/bookings/domain/models/booking.dart';
import '../../../features/claims/presentation/claim_form_page.dart';
import '../../../features/claims/presentation/my_claims_page.dart';

final _userBookingsProvider =
    FutureProvider.autoDispose.family<List<Booking>, int>((ref, userId) async {
  return BookingService().getBookingsForUser(userId);
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.valueOrNull?.profile;

    if (profile == null) {
     return Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D2280), AppColors.mobiliBlueDeep],
                ),
              ),
            ),
            const Positioned.fill(child: _TransportPattern()),
            Container(color: AppColors.mobiliBlueDeep.withValues(alpha: 0.35)),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.home_rounded, color: AppColors.white),
                  tooltip: 'Accueil',
                  onPressed: () => context.go('/'),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.mobiliYellow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.mobiliBlueDeep, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text('Non connecté',
                      style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Connectez-vous pour accéder à votre profil',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white.withValues(alpha: 0.75)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mobiliBlue,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Se connecter',
                        style: AppTextStyles.buttonPrimary
                            .copyWith(color: AppColors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bookingsAsync = ref.watch(_userBookingsProvider(profile.id));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: CustomScrollView(
        slivers: [
        SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.mobiliBlue,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.home_rounded, color: AppColors.white),
                tooltip: 'Accueil',
                onPressed: () => context.go('/'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Dégradé bleu
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D2280), AppColors.mobiliBlueDeep],
                      ),
                    ),
                  ),
                  // Pattern icônes transport
                  const Positioned.fill(child: _TransportPattern()),
                  // Overlay sombre
                  Container(
                      color: AppColors.mobiliBlueDeep.withValues(alpha: 0.3)),
                  // Contenu
                  SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.mobiliYellow,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.white, width: 3),
                            ),
                            child: profile.avatarUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      'https://api.my-mobili.com/v1/uploads/${profile.avatarUrl}',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _Initials(name: profile.fullName),
                                    ),
                                  )
                                : _Initials(name: profile.fullName),
                          ),
                          const SizedBox(height: 10),
                          Text(profile.fullName,
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                              )),
                          const SizedBox(height: 4),
                          Text(profile.email ?? profile.phone ?? '',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.white.withValues(alpha: 0.7),
                              )),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            children: profile.roles
                                .where((r) => r != 'USER')
                                .map((r) => _RoleBadge(role: r))
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                         OutlinedButton.icon(
                            onPressed: () => context.push('/edit-profile'),
                            icon: const Icon(Icons.edit_rounded,
                                size: 14, color: AppColors.white),
                            label: Text('Modifier le profil',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.white, width: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats
                  bookingsAsync.when(
                    loading: () => const _StatsLoading(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (bookings) => _StatsGrid(bookings: bookings),
                  ),
                  const SizedBox(height: 20),

                  // Mon compte
                  _Card(
                    child: Column(
                      children: [
                        const _SectionHeader(
                            icon: Icons.person_rounded, title: 'Mon compte'),
                        _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Identifiant',
                            value: profile.login),
                        const Divider(height: 1, color: AppColors.gray100),
                        _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: profile.email ?? 'Non renseigné'),
                        const Divider(height: 1, color: AppColors.gray100),
                        const Divider(height: 1, color: AppColors.gray100),
                        _InfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Téléphone',
                            value: profile.phone ?? 'Non renseigné'),
                        _InfoRow(
                          icon: Icons.verified_outlined,
                          label: 'Statut',
                          value: profile.enabled ? 'Actif' : 'Inactif',
                          valueColor: profile.enabled
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Raccourcis
                  _Card(
                    child: Column(
                      children: [
                        const _SectionHeader(
                            icon: Icons.grid_view_rounded, title: 'Raccourcis'),
                        _ActionRow(
                          icon: Icons.bookmark_rounded,
                          iconColor: AppColors.mobiliBlue,
                          label: 'Mes réservations',
                          onTap: () => context.go('/my-bookings'),
                        ),
                        const Divider(height: 1, color: AppColors.gray100),
                        _ActionRow(
                          icon: Icons.confirmation_number_rounded,
                          iconColor: AppColors.mobiliYellow,
                          label: 'Mes billets',
                          onTap: () => context.go('/tickets'),
                        ),
                        const Divider(height: 1, color: AppColors.gray100),
                        _ActionRow(
                          icon: Icons.directions_car_filled_rounded,
                          iconColor: AppColors.stationGreen,
                          label: profile.isChauffeur && profile.hasCovoiturageProfile
                              ? 'Espace covoiturage'
                              : 'Devenir conducteur covoiturage',
                          onTap: () => context.push('/covoiturage'),
                        ),
                        const Divider(height: 1, color: AppColors.gray100),
                        _ActionRow(
                          icon: Icons.report_problem_outlined,
                          iconColor: AppColors.danger,
                          label: 'Signaler un problème',
                          onTap: () => Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ClaimFormPage(),
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.gray100),
                        _ActionRow(
                          icon: Icons.history_rounded,
                          iconColor: AppColors.mobiliBlue,
                          label: 'Mes réclamations',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyClaimsPage(),
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.gray100),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Déconnexion
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                    onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: const Text('Se déconnecter ?'),
                            content: const Text(
                                'Voulez-vous vraiment vous déconnecter de Mobili ?'),
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
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Se déconnecter',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      if (confirm == true) {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            context.go('/');
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(children: [
                                    Icon(Icons.logout_rounded,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Vous avez été déconnecté.'),
                                  ]),
                                  backgroundColor: AppColors.mobiliBlue,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.white, size: 20),
                      label: Text('Se déconnecter',
                          style: AppTextStyles.buttonPrimary
                              .copyWith(color: AppColors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mobiliBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pattern icônes transport
// ─────────────────────────────────────────────────────────────────────────────

class _TransportPattern extends StatelessWidget {
  const _TransportPattern();

  static const _icons = [
    Icons.directions_bus_rounded,
    Icons.airport_shuttle_rounded,
    Icons.directions_car_rounded,
    Icons.two_wheeler_rounded,
    Icons.local_taxi_rounded,
    Icons.train_rounded,
    Icons.pedal_bike_rounded,
    Icons.directions_walk_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    const cols = 5;
    const rows = 10;
    const cellW = 80.0;
    const cellH = 38.0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final icon = _icons[(r * cols + c) % _icons.length];
        final offset = (r % 2 == 0) ? 0.0 : cellW * 0.5;
        items.add(Positioned(
          left: c * cellW + offset,
          top: r * cellH,
          child: Icon(icon,
              size: 26, color: AppColors.white.withValues(alpha: 0.07)),
        ));
      }
    }
    return Stack(children: items);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats
// ─────────────────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.bookings});
  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final total = bookings.length;
    final confirmed = bookings.where((b) => b.status == 'CONFIRMED').length;
    final pending = bookings.where((b) => b.status == 'PENDING').length;
    final cancelled = bookings.where((b) => b.status == 'CANCELLED').length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
       _StatCard(
          icon: Icons.confirmation_number_rounded,
          iconColor: AppColors.mobiliBlue,
          iconBg: AppColors.mobiliBlueFog,
          label: 'Réservations',
          value: '$total',
          onTap: () => context.go('/my-bookings'),
        ),
        _StatCard(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.success,
          iconBg: AppColors.successSoft,
          label: 'Confirmées',
          value: '$confirmed',
          onTap: () => context.go('/my-bookings?status=CONFIRMED'),
        ),
        _StatCard(
          icon: Icons.hourglass_empty_rounded,
          iconColor: AppColors.warning,
          iconBg: AppColors.warningSoft,
          label: 'En attente',
          value: '$pending',
          onTap: () => context.go('/my-bookings?status=PENDING'),
        ),
        _StatCard(
          icon: Icons.cancel_rounded,
          iconColor: AppColors.danger,
          iconBg: AppColors.dangerSoft,
          label: 'Annulées',
          value: '$cancelled',
          onTap: () => context.go('/my-bookings?status=CANCELLED'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200),
          boxShadow: AppColors.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.mobiliBlueDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      )),
                  Text(label,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.gray500, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200),
          boxShadow: AppColors.shadowSm,
        ),
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.mobiliBlue),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.titleMedium),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.gray400),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.gray400)),
                  Text(value,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: valueColor ?? AppColors.mobiliBlueDeep,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w500,
                    )),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.gray300, size: 20),
            ],
          ),
        ),
      );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (role) {
      'ADMIN' => (AppColors.adminPurpleSoft, AppColors.adminPurple),
      'PARTNER' => (const Color(0xFFEEF1FF), AppColors.mobiliBlue),
      'CHAUFFEUR' => (AppColors.stationGreenSoft, AppColors.stationGreen),
      'GARE' => (AppColors.warningSoft, AppColors.warning),
      _ => (AppColors.gray100, AppColors.gray600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role,
          style: AppTextStyles.labelSmall.copyWith(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.substring(0, 1).toUpperCase();
    return Center(
      child: Text(initials,
          style: const TextStyle(
            color: AppColors.mobiliBlueDeep,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          )),
    );
  }
}
