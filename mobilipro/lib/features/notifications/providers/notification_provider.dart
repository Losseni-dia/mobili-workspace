import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/notification_models.dart';
import '../data/notification_service.dart';

final notificationsProvider = FutureProvider<List<InboxNotification>>((
  ref,
) async {
  return NotificationService().getNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return NotificationService().getUnreadCount();
});
