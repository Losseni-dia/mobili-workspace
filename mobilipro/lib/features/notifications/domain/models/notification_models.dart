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
    this.partnerId,
    this.bookingId,
    this.claimId,
    this.subjectUserId,
    this.subjectUserName,
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
  final int? partnerId;
  final int? bookingId;
  final int? claimId;
  final int? subjectUserId;
  final String? subjectUserName;

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

 /// Parse une date UTC venant du backend et la convertit en heure locale
  /// (le backend n'envoie pas d'indicateur de fuseau, donc sans ce forçage
  /// Dart traiterait la valeur comme déjà locale).
  static DateTime _parseDate(String raw) {
    if (raw.isEmpty) return DateTime.now();
    try {
      final normalized = raw.endsWith('Z') || raw.contains('+')
          ? raw
          : '${raw}Z';
      return DateTime.parse(normalized).toLocal();
    } catch (_) {
      return DateTime.now();
    }
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
        channelMessageId: json['channelMessageId'] as int?,
       partnerGareComThreadId: json['partnerGareComThreadId'] as int?,
        partnerId: json['partnerId'] as int?,
        bookingId: json['bookingId'] as int?,
        claimId: json['claimId'] as int?,
        subjectUserId: json['subjectUserId'] as int?,
        subjectUserName: json['subjectUserName'] as String?,
      );

  // BUG corrigé : partnerId (et bookingId/claimId) n'étaient pas recopiés ici —
  // dès qu'une notification est marquée lue (ce qui arrive automatiquement au
  // tap, avant l'ouverture de la modale), ces liens disparaissaient
  // silencieusement de l'état en mémoire, cassant la navigation au rebuild
  // suivant.
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
    partnerId: partnerId,
    bookingId: bookingId,
    claimId: claimId,
    subjectUserId: subjectUserId,
    subjectUserName: subjectUserName,
  );
}
