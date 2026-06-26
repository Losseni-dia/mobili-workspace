import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum scope
// ─────────────────────────────────────────────────────────────────────────────

enum ThreadScope { all, targeted }

extension ThreadScopeX on ThreadScope {
  String get label =>
      this == ThreadScope.all ? 'Toutes les gares' : 'Gares ciblées';
  String get raw => this == ThreadScope.all ? 'ALL' : 'TARGETED';

  static ThreadScope fromRaw(String raw) =>
      raw == 'ALL' ? ThreadScope.all : ThreadScope.targeted;
}

// ─────────────────────────────────────────────────────────────────────────────
// Thread
// ─────────────────────────────────────────────────────────────────────────────

class ComThread {
  const ComThread({
    required this.id,
    required this.scope,
    required this.title,
    required this.lastActivityAt,
    required this.stationIds,
    required this.stationLabels,
  });

  final int id;
  final ThreadScope scope;
  final String title;
  final DateTime lastActivityAt;
  final List<int> stationIds;
  final List<String> stationLabels;

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(lastActivityAt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy').format(lastActivityAt);
  }

  factory ComThread.fromJson(Map<String, dynamic> json) => ComThread(
    id: json['id'] as int,
    scope: ThreadScopeX.fromRaw(json['scope'] as String? ?? 'ALL'),
    title: json['title'] as String? ?? '',
    lastActivityAt:
        DateTime.tryParse(json['lastActivityAt'] as String? ?? '') ??
        DateTime.now(),
    stationIds:
        (json['stationIds'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [],
    stationLabels:
        (json['stationLabels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Message
// ─────────────────────────────────────────────────────────────────────────────

class ComMessage {
  const ComMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.authorId,
    required this.authorFirstname,
    required this.authorLastname,
    required this.authorLogin,
  });

  final int id;
  final String body;
  final DateTime createdAt;
  final int authorId;
  final String authorFirstname;
  final String authorLastname;
  final String authorLogin;

  String get authorName {
    final full = '$authorFirstname $authorLastname'.trim();
    return full.isNotEmpty ? full : authorLogin;
  }

  String get formattedTime => DateFormat('dd/MM HH:mm').format(createdAt);

  factory ComMessage.fromJson(Map<String, dynamic> json) => ComMessage(
    id: json['id'] as int,
    body: json['body'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    authorId: (json['authorId'] as num?)?.toInt() ?? 0,
    authorFirstname: json['authorFirstname'] as String? ?? '',
    authorLastname: json['authorLastname'] as String? ?? '',
    authorLogin: json['authorLogin'] as String? ?? '',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Request DTOs
// ─────────────────────────────────────────────────────────────────────────────

class CreateThreadRequest {
  const CreateThreadRequest({
    required this.scope,
    required this.title,
    required this.firstMessage,
    this.stationIds,
  });

  final ThreadScope scope;
  final String title;
  final String firstMessage;
  final List<int>? stationIds;

  Map<String, dynamic> toJson() => {
    'scope': scope.raw,
    'title': title,
    'firstMessage': firstMessage,
    if (stationIds != null && stationIds!.isNotEmpty) 'stationIds': stationIds,
  };
}
