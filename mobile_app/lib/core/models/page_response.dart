/// Generic wrapper for Spring's paginated `Page<T>` JSON responses.
///
/// Usage:
/// ```dart
/// final page = PageResponse.fromJson(
///   json,
///   (item) => NotificationDto.fromJson(item as Map<String, dynamic>),
/// );
/// ```
class PageResponse<T> {
  const PageResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
  });

  /// Items for the current page.
  final List<T> content;

  /// Total number of items across all pages.
  final int totalElements;

  /// Total number of pages.
  final int totalPages;

  /// Current page index (0-based).
  final int number;

  /// Page size requested.
  final int size;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) {
    return PageResponse<T>(
      content: (json['content'] as List<dynamic>)
          .map(fromJsonT)
          .toList(growable: false),
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
      number: json['number'] as int,
      size: json['size'] as int,
    );
  }

  Map<String, dynamic> toJson(Object? Function(T) toJsonT) => {
        'content': content.map(toJsonT).toList(),
        'totalElements': totalElements,
        'totalPages': totalPages,
        'number': number,
        'size': size,
      };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get isFirst => number == 0;
  bool get isLast => number >= totalPages - 1;
  bool get isEmpty => content.isEmpty;
  bool get hasNextPage => !isLast;

  @override
  String toString() =>
      'PageResponse(page $number/$totalPages, $totalElements total, '
      '${content.length} items)';
}
