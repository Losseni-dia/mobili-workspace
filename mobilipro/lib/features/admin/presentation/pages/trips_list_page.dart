import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_export_helpers.dart';
import '../widgets/admin_period_selector.dart';

class TripsListDetailPage extends ConsumerStatefulWidget {
  const TripsListDetailPage({super.key});
  @override
  ConsumerState<TripsListDetailPage> createState() =>
      _TripsListDetailPageState();
}

class _TripsListDetailPageState extends ConsumerState<TripsListDetailPage> {
  AdminStatsPeriod _period = kPeriodMonth;
  String _search = '';
  int _pageSize = 20;
final _searchCtrl = TextEditingController();

  // fromAsDate/toAsDate (bornes calendaires, pas une fenêtre glissante) — voir
  // AdminStatsPeriodDates dans admin_period_selector.dart.
  ({DateTime from, DateTime to}) _tripDateRange() =>
      (from: _period.fromAsDate, to: _period.toAsDate);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = _tripDateRange();
    final effectivePeriod = (
      days: _period.days,
      fromDate: range.from,
      toDate: range.to,
    );
    final listAsync = ref.watch(
      tripListProvider((period: effectivePeriod, search: _search)),
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Trajets',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          AdminPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() {
              _period = p;
              _pageSize = 20;
            }),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {
                    _search = v;
                    _pageSize = 20;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Rechercher route ou compagnie...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gray200),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                listAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mobiliBlue,
                      ),
                    ),
                  ),
                  error: (e, _) => Text(
                    'Erreur : $e',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Aucun trajet trouvé',
                            style: TextStyle(color: AppColors.gray400),
                          ),
                        ),
                      );
                    }
                    final visible = list.take(_pageSize).toList();
                    final hasMore = list.length > _pageSize;
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${visible.length} / ${list.length} trajet(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      exportTripsCsv(list, context),
                                  icon: const Icon(
                                    Icons.table_chart_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'CSV',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      exportTripsPdf(list, context),
                                  icon: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'PDF',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...visible.map(
                          (t) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.route,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: AppColors.mobiliBlueDeep,
                                        ),
                                      ),
                                      Text(
                                        '${t.partnerName} — ${t.stationName}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                      Text(
                                        '${DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime)} — ${t.availableSeats}/${t.totalSeats} places',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _StatusPill(status: t.status),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${t.price.toStringAsFixed(0)} F',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: AppColors.proGold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (hasMore)
                          LoadMoreButton(
                            remaining: list.length - _pageSize,
                            onTap: () => setState(() => _pageSize += 20),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Étiquette de statut du trajet (Programmé/En cours/Terminé/Annulé/Brouillon) —
/// couleurs alignées sur trips_gare_page._statusConfig (mobilipro) / trip-management (web).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  (Color, Color) get _colors {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return (AppColors.gray100, AppColors.gray500);
      case 'PROGRAMMÉ':
        return (AppColors.mobiliBlueFog, AppColors.mobiliBlue);
      case 'EN_COURS':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'TERMINÉ':
        return (AppColors.gray100, AppColors.gray500);
      case 'ANNULÉ':
        return (AppColors.dangerSoft, AppColors.danger);
      default:
        return (AppColors.warningSoft, AppColors.warning);
    }
  }

  String get _label {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return 'Brouillon';
      case 'PROGRAMMÉ':
        return 'Programmé';
      case 'EN_COURS':
        return 'En cours';
      case 'TERMINÉ':
        return 'Terminé';
      case 'ANNULÉ':
        return 'Annulé';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        _label,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
