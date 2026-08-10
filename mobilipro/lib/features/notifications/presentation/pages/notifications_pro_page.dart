import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobilipro/features/admin/presentation/pages/admin_claims_page.dart';
import 'package:mobilipro/features/admin/presentation/pages/admin_gestion_page_v2.dart';
import 'package:mobilipro/features/admin/presentation/pages/partner_stats_page.dart';
import 'package:mobilipro/features/partnergarecom/presentation/pages/partner_gare_com_page.dart';

import '../../../../core/theme/app_colors.dart';
import 'package:mobilipro/features/auth/providers/auth_provider.dart';
import 'package:mobilipro/features/notifications/data/notification_service.dart';
import 'package:mobilipro/features/notifications/domain/models/notification_models.dart';
import 'package:mobilipro/features/notifications/providers/notification_provider.dart';
import 'package:mobilipro/features/partnergarecom/data/partner_gare_com_service.dart';

class NotificationsProPage extends ConsumerStatefulWidget {
  const NotificationsProPage({super.key});

  @override
  ConsumerState<NotificationsProPage> createState() =>
      _NotificationsProPageState();
}

class _NotificationsProPageState extends ConsumerState<NotificationsProPage> {
  final _service = NotificationService();
  List<InboxNotification>? _notifications;
  Timer? _timer;
  int _currentPage = 0;
  bool _hasMore = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(notificationsProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _markRead(InboxNotification notif) async {
    if (notif.read) return;
    await _service.markRead(notif.id);
    setState(() {
      _notifications = _notifications
          ?.map((n) => n.id == notif.id ? n.copyWith(read: true) : n)
          .toList();
    });
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    setState(() {
      _notifications = _notifications
          ?.map((n) => n.copyWith(read: true))
          .toList();
    });
  }

  Future<void> _delete(InboxNotification notif) async {
    setState(() {
      _notifications = _notifications?.where((n) => n.id != notif.id).toList();
    });
    try {
      await _service.deleteNotification(notif.id);
    } catch (_) {
      setState(() {
        _notifications = [...?_notifications, notif];
      });
    }
  }

  Future<void> _deleteAll() async {
    await _service.deleteAll();
    setState(() {
      _notifications = [];
      _hasMore = false;
    });
    ref.invalidate(notificationsProvider);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _currentPage + 1;
      final more = await _service.getNotifications(page: next);
      setState(() {
        _currentPage = next;
        _notifications = [...(_notifications ?? []), ...more];
        _hasMore = more.length == 20;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  void _onTap(BuildContext context, InboxNotification notif) async {
    await _markRead(notif);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notif.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.mobiliBlueDeep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notif.body,
              style: const TextStyle(color: AppColors.gray600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              notif.formattedDate,
              style: const TextStyle(color: AppColors.gray400, fontSize: 12),
            ),

          // ── Action selon type ────────────────────
            if (notif.type == 'PARTNER_SUBMISSION_PENDING' &&
                notif.partnerId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    try {
                      final partners = await ref.read(
                        adminPartnersProvider.future,
                      );
                      final partner = partners.firstWhere(
                        (p) => p.id == notif.partnerId,
                      );
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PartnerDetailPage(partner: partner),
                          ),
                        );
                      }
                  } catch (_) {
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PartnerStatsDetailPage(),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.business_rounded, size: 16),
                  label: const Text('Voir la fiche société'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliBlue,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ] else if ((notif.type == 'PARTNER_APPROVED' ||
                    notif.type == 'PARTNER_REJECTED') &&
                notif.partnerId != null) ...[
              // Même mécanisme que PARTNER_SUBMISSION_PENDING ci-dessus : la
              // société concernée par l'approbation/le rejet, pas une liste
              // generique.
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    try {
                      final partners = await ref.read(
                        adminPartnersProvider.future,
                      );
                      final partner = partners.firstWhere(
                        (p) => p.id == notif.partnerId,
                      );
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PartnerDetailPage(partner: partner),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PartnerStatsDetailPage(),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.business_rounded, size: 16),
                  label: const Text('Voir la fiche société'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliBlue,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ] else if (notif.type == 'CLAIM_SUBMITTED' &&
                notif.claimId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminClaimsPage(
                          highlightClaimId: notif.claimId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.report_problem_outlined, size: 16),
                  label: const Text('Voir la réclamation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliBlue,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ] else if (notif.partnerGareComThreadId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    try {
                      final threads = await PartnerGareComService()
                          .getThreads();
                      final thread = threads.firstWhere(
                        (t) => t.id == notif.partnerGareComThreadId,
                      );
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ThreadPage(thread: thread),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) context.go('/partner/canal');
                    }
                  },
                  icon: const Icon(Icons.forum_rounded, size: 16),
                  label: const Text('Voir le fil de discussion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliBlue,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ] else if (notif.type == 'MOBILI_ADMIN_INFO_PARTNER') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    // Admin → onglet Communications
                    final profile = ref.read(currentProfileProvider);
                    if (profile != null && profile.isAdmin) {
                      context.go('/admin/communications');
                    } else {
                      // Partenaire/chauffeur → onglet Messages Mobili
                      context.go('/partner/canal');
                    }
                  },
                  icon: const Icon(Icons.forum_rounded, size: 16),
                  label: const Text('Voir le message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliBlue,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ]else if (notif.tripId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    context.go('/gare/trips');
                  },
                  icon: const Icon(Icons.directions_bus_rounded, size: 16),
                  label: const Text('Voir les trajets'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mobiliBlue,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<InboxNotification>>>(notificationsProvider, (
      previous,
      next,
    ) {
      if (next.hasValue) {
        setState(() {
          _notifications = next.value;
          _currentPage = 0;
          _hasMore = next.value!.length == 20;
        });
      }

    });
 final notifAsync = ref.watch(notificationsProvider);

    // Filtre selon le rôle
  final notifications = _notifications ?? [];

    final unreadCount = notifications.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Tout lire',
                style: TextStyle(
                  color: AppColors.mobiliYellow,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.white),
            onSelected: (value) async {
              if (value == 'delete_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Tout supprimer ?'),
                    content: const Text(
                      'Toutes vos notifications seront supprimées définitivement.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                        ),
                        child: const Text(
                          'Supprimer',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) await _deleteAll();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text('Tout supprimer'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erreur : $e',
            style: const TextStyle(color: AppColors.gray500),
          ),
        ),
    data: (_) {
          if (notifications.isEmpty) {
            return RefreshIndicator(
              color: AppColors.mobiliBlue,
              onRefresh: () async {
                setState(() {
                  _notifications = null;
                  _currentPage = 0;
                });
                ref.invalidate(notificationsProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.mobiliBlueFog,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.mobiliBlue,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune notification',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mobiliBlueDeep,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Vos notifications apparaîtront ici.',
                            style: TextStyle(
                              color: AppColors.gray400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.mobiliBlue,
            onRefresh: () async {
              setState(() {
                _notifications = null;
                _currentPage = 0;
              });
              ref.invalidate(notificationsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                if (index == notifications.length) {
                  return Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator(
                            color: AppColors.mobiliBlue,
                          )
                        : OutlinedButton.icon(
                            onPressed: _loadMore,
                            icon: const Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                            ),
                            label: const Text('Voir plus'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.mobiliBlue,
                              side: const BorderSide(
                                color: AppColors.mobiliBlue,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                  );
                }

                final notif = notifications[index];
                return _NotifCard(
                  notification: notif,
                  onDelete: () => _delete(notif),
                  onTap: () => _onTap(context, notif),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte notification
// ─────────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final InboxNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final config = _typeConfig(notification.type);

    return Dismissible(
      key: Key('notif_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: notification.read
                ? AppColors.white
                : const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notification.read
                  ? AppColors.gray200
                  : AppColors.mobiliBlue.withValues(alpha: 0.2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: config.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(config.$1, color: config.$2, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mobiliBlueDeep,
                                fontWeight: notification.read
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!notification.read)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6, top: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.mobiliBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          color: AppColors.gray500,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            notification.formattedDate,
                            style: const TextStyle(
                              color: AppColors.gray400,
                              fontSize: 10,
                            ),
                          ),
                          if (notification.tripRoute != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mobiliBlueFog,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                notification.tripRoute!,
                                style: const TextStyle(
                                  color: AppColors.mobiliBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: AppColors.gray400,
                  ),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text('Supprimer'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _typeConfig(String type) {
    switch (type.toUpperCase()) {
      case 'GARE_STATION_NEW_BOOKING':
        return (Icons.bookmark_add_rounded, AppColors.stationGreen);
      case 'PARTNER_GARE_COM_MESSAGE':
        return (Icons.forum_rounded, AppColors.mobiliBlue);
     case 'MOBILI_ADMIN_INFO_PARTNER':
        return (Icons.support_agent_rounded, AppColors.warning);
      case 'PARTNER_SUBMISSION_PENDING':
        return (Icons.business_center_rounded, AppColors.proGold);
      case 'COV_KYC_EXPIRING_SOON':
        return (Icons.warning_amber_rounded, AppColors.warning);
      case 'COV_KYC_EXPIRED':
        return (Icons.error_rounded, AppColors.danger);
      case 'BOOKING_CANCELLED':
        return (Icons.cancel_rounded, AppColors.danger);
      case 'TRIP_CHANNEL_MESSAGE':
        return (Icons.chat_rounded, AppColors.mobiliBlue);
      case 'TICKET_ISSUED':
        return (Icons.confirmation_number_rounded, AppColors.stationGreen);
      case 'PARTNER_APPROVED':
        return (Icons.verified_rounded, AppColors.stationGreen);
      case 'PARTNER_REJECTED':
        return (Icons.block_rounded, AppColors.danger);
      case 'CLAIM_SUBMITTED':
      case 'CLAIM_STATUS_UPDATED':
        return (Icons.report_problem_outlined, AppColors.mobiliBlue);
      default:
        return (Icons.notifications_rounded, AppColors.mobiliBlue);
    }
  }
}
