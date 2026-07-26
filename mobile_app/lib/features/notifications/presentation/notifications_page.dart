import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobili/features/notifications/providers/notification_provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_app_bar.dart';
import 'package:dio/dio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.tripId,
    this.tripRoute,
    this.bookingId,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final int? tripId;
  final String? tripRoute;
  final int? bookingId;

  /// Parse une date UTC venant du backend et la convertit en heure locale
  static DateTime _parseDate(String raw) {
    if (raw.isEmpty) return DateTime.now();
    try {
      // Si la chaîne ne contient pas d'info timezone, on force UTC
      final normalized =
          raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z';
      return DateTime.parse(normalized).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return m > 0 ? 'Il y a ${h}h${m}min' : 'Il y a ${h}h';
    }
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }

factory InboxNotification.fromJson(Map<String, dynamic> json) =>
      InboxNotification(
        id: json['id'] as int,
        type: json['type'] as String? ?? 'INFO',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: _parseDate(json['createdAt'] as String? ?? ''),
        tripId: json['tripId'] as int?,
        tripRoute: json['tripRoute'] as String?,
        bookingId: json['bookingId'] as int?,
      );

  InboxNotification copyWith({bool? read}) => InboxNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        read: read ?? this.read,
        createdAt: createdAt,
        tripId: tripId,
        tripRoute: tripRoute,
        bookingId: bookingId,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;
  final Dio _dio;

  Future<List<InboxNotification>> getNotifications({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inbox/notifications',
      queryParameters: {'page': page, 'size': size},
    );
    final content = response.data?['content'] as List<dynamic>? ?? [];
    return content
        .map((e) => InboxNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getTotalPages({int size = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inbox/notifications',
      queryParameters: {'page': 0, 'size': size},
    );
    return (response.data?['totalPages'] as int?) ?? 1;
  }

  Future<int> getUnreadCount() async {
    final response = await _dio
        .get<Map<String, dynamic>>('/inbox/notifications/unread-count');
    return (response.data?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(int id) async {
    await _dio.patch<void>('/inbox/notifications/$id/read');
  }

Future<void> markAllRead() async {
    await _dio.patch<void>('/inbox/notifications/read-all');
  }

  Future<void> markAllSeen() async {
    await _dio.patch<void>('/inbox/notifications/mark-all-seen');
  }

  Future<void> deleteNotification(int id) async {
    await _dio.delete<void>('/inbox/notifications/$id');
  }

  Future<void> deleteAll() async {
    await _dio.delete<void>('/inbox/notifications');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
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
      _notifications =
          _notifications?.map((n) => n.copyWith(read: true)).toList();
    });
  }

  Future<void> _delete(InboxNotification notif) async {
    setState(() {
      _notifications = _notifications?.where((n) => n.id != notif.id).toList();
    });
    try {
      await _service.deleteNotification(notif.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification supprimée'),
            backgroundColor: AppColors.gray700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      setState(() {
        _notifications = [...?_notifications, notif];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la suppression'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);

    if (notifAsync.hasValue) {
      final newData = notifAsync.value!;
      if (_notifications == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _notifications = newData;
              _currentPage = 0;
              _hasMore = newData.length == 20;
            });
          }
        });
      }
    }

    final notifications = _notifications ?? [];
    final unreadCount = notifications.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: MobiliAppBar(
        title: 'Notifications',
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Tout lire',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.mobiliYellow,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.white),
            onSelected: (value) async {
              if (value == 'delete_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (sheetContext) => AlertDialog(
                    title: const Text('Tout supprimer ?'),
                    content: const Text(
                        'Toutes vos notifications seront supprimées définitivement.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger),
                        child: const Text('Supprimer',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _deleteAll();
                  ref.invalidate(notificationsProvider);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        color: AppColors.danger, size: 18),
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
          child: Text('Erreur : $e',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.gray500)),
        ),
        data: (_) {
          if (notifications.isEmpty) {
            return Center(
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
                    child: const Icon(Icons.notifications_none_rounded,
                        color: AppColors.mobiliBlue, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text('Aucune notification',
                      style: AppTextStyles.titleLarge
                          .copyWith(color: AppColors.mobiliBlueDeep)),
                  const SizedBox(height: 8),
                  Text('Vos notifications apparaîtront ici.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.gray400)),
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
              itemBuilder: (context, index) {
                if (index == notifications.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator(
                              color: AppColors.mobiliBlue)
                          : OutlinedButton.icon(
                              onPressed: _loadMore,
                              icon: const Icon(Icons.expand_more_rounded,
                                  size: 18),
                              label: const Text('Voir plus'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.mobiliBlue,
                                side: const BorderSide(
                                    color: AppColors.mobiliBlue),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                    ),
                  );
                }

             final notif = notifications[index];
                return _NotifCard(
                  notification: notif,
                  onDelete: () => _delete(notif),
                  onTap: () async {
                    await _markRead(notif);
                    if (!context.mounted) return;

                    // Canal trajet : ouvre directement le fil, pas de modale.
                    if (notif.type == 'TRIP_CHANNEL_MESSAGE' &&
                        notif.tripId != null) {
                      context.push(
                        '/trips/${notif.tripId}/channel?label=${Uri.encodeComponent(notif.tripRoute ?? '')}',
                      );
                      return;
                    }

                    if (context.mounted) {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (sheetContext) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notif.title,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: AppColors.mobiliBlueDeep,
                                    fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(height: 8),
                              Text(notif.body,
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: AppColors.gray600)),
                              const SizedBox(height: 8),
                              Text(notif.formattedDate,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.gray400)),
                              if (notif.tripId != null) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                 onPressed: () {
                                      Navigator.of(sheetContext).pop();
                                      if (notif.type == 'TICKET_ISSUED') {
                                        context.go(
                                            '/tickets?tripId=${notif.tripId}');
                                      } else if (notif.type ==
                                              'BOOKING_CONFIRMED' ||
                                          notif.type ==
                                              'COVOITURAGE_BOOKING_ACCEPTED' ||
                                          notif.type ==
                                              'COVOITURAGE_BOOKING_REJECTED' ||
                                          notif.type ==
                                              'COVOITURAGE_BOOKING_NO_RESPONSE' ||
                                          notif.type ==
                                              'COVOITURAGE_BOOKING_PAYMENT_EXPIRED') {
                                        context.go(notif.bookingId != null
                                            ? '/my-bookings?bookingId=${notif.bookingId}'
                                            : '/my-bookings');
                                      } else if (notif.type ==
                                              'TRIP_CHANNEL_MESSAGE' ||
                                          notif.type == 'TRIP_DELAY' ||
                                          notif.type == 'TRIP_GATE_CHANGE') {
                                        context.go('/my-bookings');
                                      } else if (notif.type ==
                                              'MOBILI_ADMIN_INFO_PARTNER' ||
                                          notif.type ==
                                              'MOBILI_ADMIN_INFO_SUPPORT') {
                                        context.push('/support');
                                      } else if (notif.tripId != null) {
                                        context.go('/trips/${notif.tripId}');
                                      }
                                    },
                                    icon: Icon(
                                      notif.type == 'TICKET_ISSUED'
                                          ? Icons.confirmation_number_rounded
                                          : Icons.directions_bus_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      notif.type == 'TICKET_ISSUED'
                                          ? 'Voir le billet'
                                          : notif.type == 'BOOKING_CONFIRMED'
                                              ? 'Voir la réservation'
                                              : (notif.type ==
                                                          'TRIP_CHANNEL_MESSAGE' ||
                                                      notif.type ==
                                                          'TRIP_DELAY' ||
                                                      notif.type ==
                                                          'TRIP_GATE_CHANGE')
                                                  ? 'Voir mes réservations'
                                                  : 'Voir le trajet',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.mobiliBlue,
                                      foregroundColor: AppColors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
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
                  },
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
            color:
                notification.read ? AppColors.white : const Color(0xFFF0F4FF),
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
                            child: Text(notification.title,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.mobiliBlueDeep,
                                  fontWeight: notification.read
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                )),
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
                      Text(notification.body,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.gray500,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(notification.formattedDate,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.gray400,
                                fontSize: 10,
                              )),
                          if (notification.tripRoute != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.mobiliBlueFog,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(notification.tripRoute!,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.mobiliBlue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 18, color: AppColors.gray400),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: AppColors.danger, size: 18),
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
      case 'BOOKING_CONFIRMED':
        return (Icons.check_circle_rounded, AppColors.stationGreen);
      case 'BOOKING_CANCELLED':
        return (Icons.cancel_rounded, AppColors.danger);
      case 'PAYMENT_SUCCESS':
        return (Icons.payments_rounded, AppColors.stationGreen);
      case 'PAYMENT_FAILED':
        return (Icons.money_off_rounded, AppColors.danger);
      case 'TRIP_UPDATE':
        return (Icons.directions_bus_rounded, AppColors.mobiliBlue);
      case 'TRIP_CANCELLED':
        return (Icons.bus_alert_rounded, AppColors.warning);
      case 'PROMO':
        return (Icons.local_offer_rounded, AppColors.mobiliYellow);
      case 'TRIP_CHANNEL_MESSAGE':
        return (Icons.campaign_rounded, AppColors.mobiliBlue);
      case 'PARTNER_NEW_BOOKING':
        return (Icons.bookmark_add_rounded, AppColors.stationGreen);
      case 'TRIP_DELAY':
        return (Icons.schedule_rounded, AppColors.warning);
      case 'TRIP_GATE_CHANGE':
        return (Icons.location_on_rounded, AppColors.warning);
        case 'MOBILI_ADMIN_INFO_PARTNER':
        return (Icons.support_agent_rounded, AppColors.mobiliBlue);
      case 'MOBILI_ADMIN_INFO_SUPPORT':
        return (Icons.support_agent_rounded, AppColors.mobiliBlue);
      default:
        return (Icons.notifications_rounded, AppColors.mobiliBlue);
    }
  }
}
