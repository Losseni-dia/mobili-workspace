// ─────────────────────────────────────────────────────────────────────────────
// InboxNotification — modèle mobilipro
// Champs supplémentaires vs mobile_app : partnerGareComThreadId
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
    this.channelMessageId,
    this.partnerGareComThreadId,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final int? tripId;
  final String? tripRoute;
  final int? channelMessageId;
  final int? partnerGareComThreadId;

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
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  factory InboxNotification.fromJson(Map<String, dynamic> json) =>
      InboxNotification(
        id: json['id'] as int,
        type: json['type'] as String? ?? 'INFO',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        tripId: json['tripId'] as int?,
        tripRoute: json['tripRoute'] as String?,
        channelMessageId: json['channelMessageId'] as int?,
        partnerGareComThreadId: json['partnerGareComThreadId'] as int?,
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
    channelMessageId: channelMessageId,
    partnerGareComThreadId: partnerGareComThreadId,
  );
}
