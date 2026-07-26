import 'package:dio/dio.dart';
import 'package:mobilipro/features/partnergarecom/domain/models/partner_gare_com_models.dart';
import '../../../../core/network/api_client.dart';


// ─────────────────────────────────────────────────────────────────────────────
// PartnerGareComService
// ─────────────────────────────────────────────────────────────────────────────

class PartnerGareComService {
  PartnerGareComService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  static const _base = '/partner-gare-com';

  // ── Threads ────────────────────────────────────────────────────────────────

  Future<List<ComThread>> getThreads() async {
    final res = await _dio.get<List<dynamic>>('$_base/threads');
    return (res.data ?? [])
        .map((e) => ComThread.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ComThread> createThread(CreateThreadRequest req) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_base/threads',
      data: req.toJson(),
    );
    return ComThread.fromJson(res.data!);
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  Future<List<ComMessage>> getMessages(int threadId) async {
    final res = await _dio.get<List<dynamic>>(
      '$_base/threads/$threadId/messages',
    );
    return (res.data ?? [])
        .map((e) => ComMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ComMessage> postMessage(int threadId, String body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_base/threads/$threadId/messages',
      data: {'body': body},
    );
    return ComMessage.fromJson(res.data!);
  }

  Future<void> deleteThread(int threadId, {required bool forEveryone}) async {
    await _dio.delete<void>(
      '$_base/threads/$threadId',
      queryParameters: {'mode': forEveryone ? 'EVERYONE' : 'ME'},
    );
  }
}
