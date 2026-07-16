import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE
// ═══════════════════════════════════════════════════════════════════════════

class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.occurredAt,
    required this.eventType,
    required this.detail,
  });
  final int id;
  final String occurredAt;
  final String eventType;
  final String detail;

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
    id: (json['id'] as num).toInt(),
    occurredAt: json['occurredAt'] as String? ?? '',
    eventType: json['eventType'] as String? ?? '',
    detail: json['detail'] as String? ?? '—',
  );

  // Icône + couleur selon le type d'événement
  (IconData, Color) get config {
    switch (eventType) {
      case 'FAILED_LOGIN':
        return (Icons.lock_outline_rounded, AppColors.danger);
      case 'BOOKING_CREATED':
        return (Icons.bookmark_add_rounded, AppColors.mobiliBlue);
      case 'BOOKING_PAID':
        return (Icons.payments_rounded, AppColors.stationGreen);
      case 'TRIP_PUBLISHED':
        return (Icons.directions_bus_rounded, AppColors.proGold);
      case 'SEARCH_NO_RESULT':
        return (Icons.search_off_rounded, AppColors.warning);
      case 'SERVER_ERROR':
        return (Icons.error_outline_rounded, AppColors.danger);
      default:
        return (Icons.info_outline_rounded, AppColors.gray400);
    }
  }

  String get typeLabel {
    switch (eventType) {
      case 'FAILED_LOGIN':
        return 'Connexion échouée';
      case 'BOOKING_CREATED':
        return 'Réservation créée';
      case 'BOOKING_PAID':
        return 'Paiement confirmé';
      case 'TRIP_PUBLISHED':
        return 'Trajet publié';
      case 'SEARCH_NO_RESULT':
        return 'Recherche sans résultat';
      case 'SERVER_ERROR':
        return 'Erreur serveur';
      default:
        return eventType;
    }
  }

  // Date lisible : "2026-06-24T23:30:55" → "24/06 23:30"
  String get formattedDate {
    try {
      final dt = DateTime.parse(occurredAt);
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$d/$mo $h:$mi';
    } catch (_) {
      return occurredAt.length > 16 ? occurredAt.substring(0, 16) : occurredAt;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

final activityLogsProvider = FutureProvider.autoDispose
    .family<List<ActivityLog>, int>((ref, limit) async {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin/analytics/recent-events',
        queryParameters: {'limit': limit},
      );
      return (res.data ?? [])
          .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
    });

// ═══════════════════════════════════════════════════════════════════════════
// PAGE LOGS D'ACTIVITÉ
// ═══════════════════════════════════════════════════════════════════════════

class AdminActivityLogsPage extends ConsumerStatefulWidget {
  const AdminActivityLogsPage({super.key});

  @override
  ConsumerState<AdminActivityLogsPage> createState() =>
      _AdminActivityLogsPageState();
}

class _AdminActivityLogsPageState extends ConsumerState<AdminActivityLogsPage> {
  String _typeFilter = 'TOUS';
  String _search = '';
  final _searchCtrl = TextEditingController();
  int _limit = 50;

  static const _types = [
    'TOUS',
    'FAILED_LOGIN',
    'BOOKING_CREATED',
    'BOOKING_PAID',
    'TRIP_PUBLISHED',
    'SEARCH_NO_RESULT',
    'SERVER_ERROR',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogsProvider(_limit));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Logs d\'activité',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(activityLogsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Recherche ──────────────────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Rechercher dans les détails...',
                hintStyle: const TextStyle(
                  color: AppColors.gray400,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.gray400,
                  size: 20,
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: AppColors.gray400,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.gray50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.gray200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.gray200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.mobiliBlue,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

         // ── Filtre type ────────────────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Type :',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _typeFilter,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.gray400,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mobiliBlueDeep,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _types.map((t) {
                          final log = t != 'TOUS'
                              ? ActivityLog(
                                  id: 0,
                                  occurredAt: '',
                                  eventType: t,
                                  detail: '',
                                )
                              : null;
                          final label = t == 'TOUS'
                              ? 'Tous les événements'
                              : log!.typeLabel;
                          final (icon, color) =
                              log?.config ??
                              (Icons.list_rounded, AppColors.mobiliBlue);
                          return DropdownMenuItem<String>(
                            value: t,
                            child: Row(
                              children: [
                                Icon(icon, size: 14, color: color),
                                const SizedBox(width: 8),
                                Text(label),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _typeFilter = v!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.gray100),

          // ── Liste ──────────────────────────────────────────────────
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text('$e', style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(activityLogsProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (logs) {
                var filtered = logs;
                if (_typeFilter != 'TOUS') {
                  filtered = filtered
                      .where((l) => l.eventType == _typeFilter)
                      .toList();
                }
                if (_search.isNotEmpty) {
                  final q = _search.toLowerCase();
                  filtered = filtered
                      .where(
                        (l) =>
                            l.detail.toLowerCase().contains(q) ||
                            l.typeLabel.toLowerCase().contains(q),
                      )
                      .toList();
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 48,
                          color: AppColors.gray300,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Aucun événement trouvé',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async => ref.invalidate(activityLogsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length + 1,
                    itemBuilder: (_, i) {
                      // Bouton charger plus en bas
                      if (i == filtered.length) {
                        if (logs.length < _limit) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _limit += 50),
                            icon: const Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                            ),
                            label: const Text('Charger 50 de plus'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.mobiliBlue,
                              side: const BorderSide(
                                color: AppColors.mobiliBlue,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        );
                      }
                      return _LogCard(log: filtered[i]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE LOG
// ═══════════════════════════════════════════════════════════════════════════

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final ActivityLog log;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = log.config;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        log.formattedDate,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    log.detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${log.id}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.gray300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
