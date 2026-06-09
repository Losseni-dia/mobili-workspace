import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifications_page.dart';

final notificationsProvider =
    FutureProvider<List<InboxNotification>>((ref) async {
  return NotificationService().getNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return NotificationService().getUnreadCount();
});
