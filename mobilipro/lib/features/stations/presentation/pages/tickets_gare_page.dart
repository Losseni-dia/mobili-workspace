import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:mobilipro/core/network/api_client.dart';
import 'package:mobilipro/core/theme/app_colors.dart';
import 'package:mobilipro/features/partner/presentation/widgets/partner_period_selector.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class GareTicketItem {
  const GareTicketItem({
    required this.id,
    required this.ticketNumber,
    required this.passengerName,
    required this.route,
    required this.bookingDate,
    required this.amountPaid,
    required this.status,
    required this.seatNumber,
    required this.scanned,
  });
  final int id;
  final String ticketNumber, passengerName, route, status, seatNumber;
  final DateTime bookingDate;
  final double amountPaid;
  final bool scanned;

  factory GareTicketItem.fromJson(Map<String, dynamic> j) => GareTicketItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    ticketNumber: j['ticketNumber'] as String? ?? '',
    passengerName: j['passengerName'] as String? ?? '',
    route: j['route'] as String? ?? '',
    bookingDate:
        DateTime.tryParse(j['bookingDate'] as String? ?? '') ?? DateTime.now(),
    amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
    status: j['status'] as String? ?? '',
    seatNumber: j['seatNumber'] as String? ?? '',
    scanned: j['scanned'] as bool? ?? false,
  );
}

final gareTicketsRangeProvider = FutureProvider.autoDispose
    .family<List<GareTicketItem>, ({PartnerPeriod period, String search})>((
      ref,
      args,
    ) async {
      final f = DateFormat('yyyy-MM-dd');
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/tickets/partner/my-tickets/range',
        queryParameters: {
          'fromDate': f.format(args.period.fromAsDate),
          'toDate': f.format(args.period.toAsDate),
          if (args.search.isNotEmpty) 'search': args.search,
        },
      );
      return (res.data ?? [])
          .map((e) => GareTicketItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

class TicketsGarePage extends ConsumerStatefulWidget {
  const TicketsGarePage({super.key});
  @override
  ConsumerState<TicketsGarePage> createState() => _TicketsGarePageState();
}

class _TicketsGarePageState extends ConsumerState<TicketsGarePage> {
  PartnerPeriod _period = PartnerPeriod.week;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportCsv(List<GareTicketItem> tickets) async {
    final rows = [
      [
        'N° Ticket',
        'Passager',
        'Trajet',
        'Date',
        'Montant FCFA',
        'Statut',
        'Siège',
        'Scanné',
      ],
      ...tickets.map(
        (t) => [
          t.ticketNumber,
          t.passengerName,
          t.route,
          DateFormat('dd/MM/yyyy HH:mm').format(t.bookingDate),
          t.amountPaid.toStringAsFixed(0),
          t.status,
          t.seatNumber,
          t.scanned ? 'Oui' : 'Non',
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/tickets_gare_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], subject: 'Tickets — Mobili');
  }

  Future<void> _exportPdf(List<GareTicketItem> tickets) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            'Tickets vendus',
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
              'N° Ticket',
              'Passager',
              'Trajet',
              'Date',
              'Montant',
              'Statut',
            ],
            data: tickets
                .map(
                  (t) => [
                    t.ticketNumber,
                    t.passengerName,
                    t.route,
                    DateFormat('dd/MM/yy HH:mm').format(t.bookingDate),
                    '${t.amountPaid.toStringAsFixed(0)} F',
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
      '${dir.path}/tickets_gare_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: 'Tickets — Mobili');
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(
      gareTicketsRangeProvider((period: _period, search: _search)),
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Tickets vendus',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          PartnerPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un passager...',
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
          ),
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (tickets) => tickets.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun ticket sur cette période',
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
                              '${tickets.length} ticket(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _exportCsv(tickets),
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
                                  onPressed: () => _exportPdf(tickets),
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
                        ...tickets.map(
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
                                        t.ticketNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: AppColors.mobiliBlueDeep,
                                        ),
                                      ),
                                      Text(
                                        '${t.passengerName} — ${t.route}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'dd/MM/yy HH:mm',
                                        ).format(t.bookingDate),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${t.amountPaid.toStringAsFixed(0)} F',
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
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
