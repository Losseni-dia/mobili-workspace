import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:mobilipro/features/partner/presentation/widgets/partner_station_filter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/partner_period_selector.dart';

class PartnerTripItem {
  const PartnerTripItem({
    required this.id,
    required this.route,
    required this.departureDateTime,
    required this.totalSeats,
    required this.availableSeats,
    required this.price,
    required this.status,
    required this.stationName,
  });
  final int id, totalSeats, availableSeats;
  final String route, status;
  final DateTime departureDateTime;
  final double price;
  /// Gare de départ assignée à ce trajet — voir Trip.stationName (backend), déjà consommé côté
  /// web (trip-management.component).
  final String? stationName;

  factory PartnerTripItem.fromJson(Map<String, dynamic> j) => PartnerTripItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    route: '${j['departureCity'] ?? ''} → ${j['arrivalCity'] ?? ''}',
    departureDateTime:
        DateTime.tryParse(j['departureDateTime'] as String? ?? '') ??
        DateTime.now(),
    totalSeats: (j['totalSeats'] as num?)?.toInt() ?? 0,
    availableSeats: (j['availableSeats'] as num?)?.toInt() ?? 0,
    price: (j['price'] as num?)?.toDouble() ?? 0,
    status: j['status'] as String? ?? '',
    stationName: j['stationName'] as String?,
  );
}

final partnerTripsRangeProvider = FutureProvider.autoDispose
    .family<
      List<PartnerTripItem>,
      ({PartnerPeriod period, int? stationId, DateTime from, DateTime to})
    >((ref, args) async {
      final f = DateFormat('yyyy-MM-dd');
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/trips/my-trips/range',
        queryParameters: {
          'fromDate': f.format(args.from),
          'toDate': f.format(args.to),
          if (args.stationId != null) 'stationId': args.stationId,
        },
      );
      return (res.data ?? [])
          .map((e) => PartnerTripItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

class PartnerTripsListPage extends ConsumerStatefulWidget {
  const PartnerTripsListPage({super.key});
  @override
  ConsumerState<PartnerTripsListPage> createState() =>
      _PartnerTripsListPageState();
}

class _PartnerTripsListPageState extends ConsumerState<PartnerTripsListPage> {
  PartnerPeriod _period = PartnerPeriod.week;
  int? _stationId;

  // fromAsDate/toAsDate (bornes calendaires, pas une fenêtre glissante) — voir
  // PartnerPeriod dans partner_period_selector.dart.
  ({DateTime from, DateTime to}) _tripDateRange() =>
      (from: _period.fromAsDate, to: _period.toAsDate);

  Future<void> _exportCsv(List<PartnerTripItem> trips) async {
    final rows = [
      [
        'Trajet',
        'Gare',
        'Départ',
        'Places totales',
        'Places restantes',
        'Prix FCFA',
        'Statut',
      ],
      ...trips.map(
        (t) => [
          t.route,
          t.stationName ?? '—',
          DateFormat('dd/MM/yyyy HH:mm').format(t.departureDateTime),
          '${t.totalSeats}',
          '${t.availableSeats}',
          t.price.toStringAsFixed(0),
          t.status,
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/mes_trajets_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Mes trajets — Mobili');
  }

  Future<void> _exportPdf(List<PartnerTripItem> trips) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            'Mes trajets',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: ['Trajet', 'Gare', 'Départ', 'Places', 'Prix', 'Statut'],
            data: trips
                .map(
                  (t) => [
                    t.route,
                    t.stationName ?? '—',
                    DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime),
                    '${t.availableSeats}/${t.totalSeats}',
                    '${t.price.toStringAsFixed(0)} F',
                    t.status,
                  ],
                )
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/mes_trajets_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Mes trajets — Mobili');
  }

  @override
 @override
  Widget build(BuildContext context) {
   final range = _tripDateRange();
    final tripsAsync = ref.watch(
      partnerTripsRangeProvider((
        period: _period,
        stationId: _stationId,
        from: range.from,
        to: range.to,
      )),
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Mes trajets',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          PartnerPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          PartnerStationFilter(
            selectedStationId: _stationId,
            onChanged: (id) => setState(() => _stationId = id),
          ),
          Expanded(
            child: tripsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (trips) => trips.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun trajet sur cette période',
                        style: TextStyle(color: AppColors.gray400),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${trips.length} trajet(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _exportCsv(trips),
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
                                  onPressed: () => _exportPdf(trips),
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
                        ...trips.map(
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
                                      if (t.stationName != null && t.stationName!.isNotEmpty)
                                        Text(
                                          '🏤 ${t.stationName}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.stationGreen,
                                          ),
                                        ),
                                      Text(
                                        '${DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime)} — ${t.availableSeats}/${t.totalSeats} places',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.gray500,
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
                      ],
                    ),
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
