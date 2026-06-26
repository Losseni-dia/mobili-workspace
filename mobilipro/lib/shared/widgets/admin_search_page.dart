import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/features/admin/presentation/pages/admin_gestion_page_v2.dart';

import '../../../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PAGE RECHERCHE GLOBALE ADMIN
// ═══════════════════════════════════════════════════════════════════════════

class AdminSearchPage extends ConsumerStatefulWidget {
  const AdminSearchPage({super.key});

  @override
  ConsumerState<AdminSearchPage> createState() => _AdminSearchPageState();
}

class _AdminSearchPageState extends ConsumerState<AdminSearchPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(adminPartnersProvider);
    final usersAsync = ref.watch(adminUsersProvider);
    final driversAsync = ref.watch(adminCovoiturageDriversProvider);

    // Résultats filtrés
    final q = _query.toLowerCase().trim();

    final partners = q.isEmpty
        ? <AdminPartner>[]
        : (partnersAsync.valueOrNull ?? [])
              .where(
                (p) =>
                    !p.covoiturageSoloPool &&
                    (p.name.toLowerCase().contains(q) ||
                        (p.ownerName ?? '').toLowerCase().contains(q) ||
                        (p.email ?? '').toLowerCase().contains(q) ||
                        (p.phone ?? '').contains(q)),
              )
              .toList();

    final users = q.isEmpty
        ? <AdminUser>[]
        : (usersAsync.valueOrNull ?? [])
              .where(
                (u) =>
                    u.fullName.toLowerCase().contains(q) ||
                    (u.email ?? '').toLowerCase().contains(q) ||
                    (u.linkedCompanyName ?? '').toLowerCase().contains(q) ||
                    (u.stationName ?? '').toLowerCase().contains(q),
              )
              .toList();

    final drivers = q.isEmpty
        ? <CovoiturageSoloDriver>[]
        : (driversAsync.valueOrNull ?? [])
              .where(
                (d) =>
                    d.fullName.toLowerCase().contains(q) ||
                    (d.email ?? '').toLowerCase().contains(q),
              )
              .toList();

    final totalResults = partners.length + users.length + drivers.length;
    final isLoading =
        partnersAsync.isLoading ||
        usersAsync.isLoading ||
        driversAsync.isLoading;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
           style: const TextStyle(
              color: AppColors.mobiliBlueDeep,
              fontSize: 15,
            ),
            cursorColor: AppColors.mobiliYellow,
            decoration: InputDecoration(
              hintText: 'Rechercher un utilisateur, partenaire...',
             hintStyle: const TextStyle(
                color: Color(0xAAFFFFFF),
                fontSize: 14,
              ),
              border: InputBorder.none,
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: isLoading && q.isNotEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.mobiliBlue),
            )
          : q.isEmpty
          ? _EmptySearch()
          : totalResults == 0
          ? _NoResults(query: _query)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Résumé ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mobiliBlueFog,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: AppColors.mobiliBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$totalResults résultat(s) pour "$_query"',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mobiliBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Partenaires ──────────────────────────────────
                if (partners.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(
                    icon: Icons.business_rounded,
                    label: 'Partenaires',
                    count: partners.length,
                    color: AppColors.proGold,
                  ),
                  const SizedBox(height: 8),
                  ...partners.map(
                    (p) => _PartnerResultCard(
                      partner: p,
                      query: _query,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PartnerDetailPage(partner: p),
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Utilisateurs ─────────────────────────────────
                if (users.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(
                    icon: Icons.people_rounded,
                    label: 'Utilisateurs',
                    count: users.length,
                    color: AppColors.mobiliBlue,
                  ),
                  const SizedBox(height: 8),
                  ...users.map(
                    (u) => _UserResultCard(
                      user: u,
                      query: _query,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserDetailPage(
                            userId: u.id,
                            displayName: u.fullName,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Covoiturage ───────────────────────────────────
                if (drivers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(
                    icon: Icons.directions_car_rounded,
                    label: 'Chauffeurs covoiturage',
                    count: drivers.length,
                    color: AppColors.stationGreen,
                  ),
                  const SizedBox(height: 8),
                  ...drivers.map(
                    (d) => _DriverResultCard(
                      driver: d,
                      query: _query,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserDetailPage(
                            userId: d.id,
                            displayName: d.fullName,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTES RÉSULTATS
// ═══════════════════════════════════════════════════════════════════════════

class _PartnerResultCard extends StatelessWidget {
  const _PartnerResultCard({
    required this.partner,
    required this.query,
    required this.onTap,
  });
  final AdminPartner partner;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, badgeColor) = switch (partner.approvalStatus) {
      'PENDING' => ('En attente', AppColors.warning),
      'REJECTED' => ('Rejeté', AppColors.danger),
      _ =>
        partner.enabled
            ? ('Actif', AppColors.stationGreen)
            : ('Inactif', AppColors.danger),
    };

    return _ResultCard(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.proGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.business_rounded,
          color: AppColors.proGold,
          size: 22,
        ),
      ),
      title: _HighlightText(text: partner.name, query: query),
      subtitle: partner.ownerName != null
          ? _HighlightText(
              text: partner.ownerName!,
              query: query,
              style: const TextStyle(fontSize: 11, color: AppColors.gray500),
            )
          : null,
      trailing: _Badge(label: badgeLabel, color: badgeColor),
      meta: partner.email,
    );
  }
}

class _UserResultCard extends StatelessWidget {
  const _UserResultCard({
    required this.user,
    required this.query,
    required this.onTap,
  });
  final AdminUser user;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ResultCard(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: user.enabled ? AppColors.mobiliBlueFog : AppColors.gray100,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            user.initial,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: user.enabled ? AppColors.mobiliBlue : AppColors.gray400,
              fontSize: 16,
            ),
          ),
        ),
      ),
      title: _HighlightText(text: user.fullName, query: query),
      subtitle: user.email != null
          ? _HighlightText(
              text: user.email!,
              query: query,
              style: const TextStyle(fontSize: 11, color: AppColors.gray500),
            )
          : null,
      trailing: _Badge(
        label: user.enabled ? 'Actif' : 'Inactif',
        color: user.enabled ? AppColors.stationGreen : AppColors.danger,
      ),
      meta: user.linkedCompanyName,
      tags: user.roles,
    );
  }
}

class _DriverResultCard extends StatelessWidget {
  const _DriverResultCard({
    required this.driver,
    required this.query,
    required this.onTap,
  });
  final CovoiturageSoloDriver driver;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (kycLabel, kycColor) = switch (driver.kycStatus) {
      'APPROVED' => ('Approuvé', AppColors.stationGreen),
      'PENDING' => ('En attente', AppColors.warning),
      'REJECTED' => ('Rejeté', AppColors.danger),
      _ => ('—', AppColors.gray400),
    };

    return _ResultCard(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kycColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            driver.initial,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: kycColor,
              fontSize: 16,
            ),
          ),
        ),
      ),
      title: _HighlightText(text: driver.fullName, query: query),
      subtitle: driver.email != null
          ? _HighlightText(
              text: driver.email!,
              query: query,
              style: const TextStyle(fontSize: 11, color: AppColors.gray500),
            )
          : null,
      trailing: _Badge(label: kycLabel, color: kycColor),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.onTap,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.meta,
    this.tags,
  });
  final VoidCallback onTap;
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget trailing;
  final String? meta;
  final List<String>? tags;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (subtitle != null) ...[const SizedBox(height: 2), subtitle!],
                if (meta != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.business_rounded,
                        size: 10,
                        color: AppColors.gray400,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          meta!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.gray400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (tags != null && tags!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: tags!
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mobiliBlue.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.mobiliBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              trailing,
              const SizedBox(height: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.gray300,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

/// Texte avec les occurrences de [query] surlignées en jaune
class _HighlightText extends StatelessWidget {
  const _HighlightText({required this.text, required this.query, this.style});
  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ??
        const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.mobiliBlueDeep,
        );
    if (query.isEmpty) return Text(text, style: baseStyle);

    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (idx > start)
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + q.length),
          style: baseStyle.copyWith(
            backgroundColor: AppColors.mobiliYellow.withValues(alpha: 0.4),
            color: AppColors.mobiliBlueDeep,
          ),
        ),
      );
      start = idx + q.length;
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
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
          child: const Icon(
            Icons.search_rounded,
            color: AppColors.mobiliBlue,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Recherche globale',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.mobiliBlueDeep,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tapez un nom, email, compagnie...',
          style: TextStyle(color: AppColors.gray400, fontSize: 13),
        ),
      ],
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.search_off_rounded,
          size: 48,
          color: AppColors.gray300,
        ),
        const SizedBox(height: 12),
        Text(
          'Aucun résultat pour "$query"',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.mobiliBlueDeep,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Essayez un autre terme',
          style: TextStyle(color: AppColors.gray400, fontSize: 13),
        ),
      ],
    ),
  );
}
