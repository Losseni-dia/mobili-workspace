import 'package:dio/dio.dart';
import '../../../../../core/network/api_client.dart';
import '../domain/models/notification_models.dart';

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

  Future<int> getUnreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inbox/notifications/unread-count',
    );
    return (response.data?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(int id) async {
    await _dio.patch<void>('/inbox/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _dio.patch<void>('/inbox/notifications/read-all');
  }

  Future<void> deleteNotification(int id) async {
    await _dio.delete<void>('/inbox/notifications/$id');
  }

  Future<void> deleteAll() async {
    await _dio.delete<void>('/inbox/notifications');
  }
}
