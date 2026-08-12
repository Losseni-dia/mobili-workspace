import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/partner_period_selector.dart';
import '../widgets/partner_station_filter.dart';

class PartnerBookingItem {
  const PartnerBookingItem({
    required this.id,
    required this.reference,
    required this.tripRoute,
    required this.bookingDate,
    required this.numberOfSeats,
    required this.totalPrice,
    required this.status,
    this.ticketsTotalAmount,
    this.luggageFee = 0,
  });
  final int id, numberOfSeats;
  final String reference, tripRoute, status;
  final DateTime bookingDate;
  final double totalPrice;

  /// Somme des prix de tickets seule (hors forfait client) — null sur les réservations
  /// antérieures au forfait. Voir [grossAmount].
  final double? ticketsTotalAmount;
  final double luggageFee;

  /// Vente brute de la compagnie — JAMAIS totalPrice, qui inclut le forfait client
  /// (jamais reversé à la compagnie). Même formule que PartnerTransactionResponse.grossAmount
  /// côté backend, pour que ce chiffre reste toujours aligné avec la page Transactions.
  double get grossAmount =>
      ticketsTotalAmount != null ? ticketsTotalAmount! + luggageFee : totalPrice;

  factory PartnerBookingItem.fromJson(Map<String, dynamic> j) =>
      PartnerBookingItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        reference: j['reference'] as String? ?? '',
        tripRoute:
            j['tripRoute'] as String? ??
            '${j['departureCity'] ?? ''} → ${j['arrivalCity'] ?? ''}',
        bookingDate:
            DateTime.tryParse(
              j['bookingDate'] as String? ?? j['date'] as String? ?? '',
            ) ??
            DateTime.now(),
        numberOfSeats: (j['numberOfSeats'] as num?)?.toInt() ?? 0,
        totalPrice: (j['totalPrice'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
        ticketsTotalAmount: (j['ticketsTotalAmount'] as num?)?.toDouble(),
        luggageFee: (j['luggageFee'] as num?)?.toDouble() ?? 0,
      );
}

final partnerBookingsRangeProvider = FutureProvider.autoDispose
    .family<List<PartnerBookingItem>, ({PartnerPeriod period, int? stationId})>(
      (ref, args) async {
        final f = DateFormat('yyyy-MM-dd');
        final res = await ApiClient.instance.dio.get<List<dynamic>>(
         '/bookings/partner/my-bookings/range',
          queryParameters: {
            'fromDate': f.format(args.period.fromAsDate),
            'toDate': f.format(args.period.toAsDate),
            if (args.stationId != null) 'stationId': args.stationId,
          },
        );
        return (res.data ?? [])
            .map((e) => PartnerBookingItem.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );

class PartnerBookingsListPage extends ConsumerStatefulWidget {
  const PartnerBookingsListPage({super.key, this.highlightBookingId});

  /// Arrivée depuis une notification PARTNER_NEW_BOOKING — surligne et
  /// scrolle vers cette réservation précise (période élargie automatiquement
  /// pour être sûr qu'elle apparaisse, quelle que soit sa date).
  final int? highlightBookingId;

  @override
  ConsumerState<PartnerBookingsListPage> createState() =>
      _PartnerBookingsListPageState();
}

class _PartnerBookingsListPageState
    extends ConsumerState<PartnerBookingsListPage> {
  late PartnerPeriod _period;
  int? _stationId;
  int? _highlightedBookingId;
  final Map<int, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _highlightedBookingId = widget.highlightBookingId;
    if (widget.highlightBookingId != null) {
      final now = DateTime.now();
      _period = PartnerPeriod(
        mode: PartnerPeriodMode.custom,
        customFrom: now.subtract(const Duration(days: 365)),
        customTo: now.add(const Duration(days: 90)),
      );
    } else {
      _period = PartnerPeriod.week;
    }
  }

  GlobalKey _keyFor(int bookingId) =>
      _cardKeys.putIfAbsent(bookingId, () => GlobalKey());

  void _scrollToHighlighted() {
    final id = _highlightedBookingId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cardKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightedBookingId = null);
      });
    });
  }

  Future<void> _exportCsv(List<PartnerBookingItem> bookings) async {
    final rows = [
      ['Référence', 'Trajet', 'Date', 'Places', 'Montant FCFA', 'Statut'],
      ...bookings.map(
        (b) => [
          b.reference,
          b.tripRoute,
          DateFormat('dd/MM/yyyy HH:mm').format(b.bookingDate),
          '${b.numberOfSeats}',
          b.grossAmount.toStringAsFixed(0),
          b.status,
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/mes_reservations_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Mes réservations — Mobili');
  }

  Future<void> _exportPdf(List<PartnerBookingItem> bookings) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            'Mes réservations',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: [
              'Référence',
              'Trajet',
              'Date',
              'Places',
              'Montant',
              'Statut',
            ],
            data: bookings
                .map(
                  (b) => [
                    b.reference,
                    b.tripRoute,
                    DateFormat('dd/MM/yy HH:mm').format(b.bookingDate),
                    '${b.numberOfSeats}',
                    '${b.grossAmount.toStringAsFixed(0)} F',
                    b.status,
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
      '${dir.path}/mes_reservations_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Mes réservations — Mobili');
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(
      partnerBookingsRangeProvider((period: _period, stationId: _stationId)),
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Mes réservations',
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
            child: bookingsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (bookings) {
                _scrollToHighlighted();
                return bookings.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucune réservation sur cette période',
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
                              '${bookings.length} réservation(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _exportCsv(bookings),
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
                                  onPressed: () => _exportPdf(bookings),
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
                        ...bookings.map(
                          (b) => Container(
                            key: _keyFor(b.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: b.id == _highlightedBookingId
                                  ? AppColors.mobiliBlueFog
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: b.id == _highlightedBookingId
                                    ? AppColors.mobiliBlue
                                    : AppColors.gray200,
                                width: b.id == _highlightedBookingId ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.reference,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: AppColors.mobiliBlueDeep,
                                        ),
                                      ),
                                      Text(
                                        '${b.tripRoute} — ${DateFormat('dd/MM/yy HH:mm').format(b.bookingDate)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                      Text(
                                        '${b.numberOfSeats} place(s) — ${b.status}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${b.grossAmount.toStringAsFixed(0)} F',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.proGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}
