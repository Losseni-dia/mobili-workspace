import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../partner/presentation/widgets/partner_period_selector.dart';

/// Une ligne = une réservation payée sur cette gare. Ne récupère QUE la vente brute
/// (montant total) depuis PartnerTransactionResponse — commission/net compagnie ne
/// concernent jamais la gare, on ne parse même pas ces champs ici.
class GareTransaction {
  const GareTransaction({
    required this.bookingId,
    required this.reference,
    required this.date,
    required this.departureDateTime,
    required this.route,
    required this.grossAmount,
    required this.status,
  });

  final int bookingId;
  final String reference, route, status;
  final DateTime date;
  /// Date de départ du voyage — distincte de date (date de réservation).
  final DateTime? departureDateTime;
  final double grossAmount;

  factory GareTransaction.fromJson(Map<String, dynamic> j) => GareTransaction(
    bookingId: (j['bookingId'] as num?)?.toInt() ?? 0,
    reference: j['reference'] as String? ?? '',
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    departureDateTime: DateTime.tryParse(
      j['departureDateTime'] as String? ?? '',
    ),
    route: j['route'] as String? ?? '',
    grossAmount: (j['grossAmount'] as num?)?.toDouble() ?? 0,
    status: j['status'] as String? ?? '',
  );
}

// Même endpoint que côté partenaire (déjà ouvert à ROLE_GARE/ROLE_STATION, déjà scopé
// sur la gare connectée côté serveur) — pas besoin d'un nouveau backend.
final gareTransactionsRangeProvider = FutureProvider.autoDispose
    .family<List<GareTransaction>, PartnerPeriod>((ref, period) async {
      final f = DateFormat('yyyy-MM-dd');
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/bookings/partner/transactions/range',
        queryParameters: {
          'fromDate': f.format(period.fromAsDate),
          'toDate': f.format(period.toAsDate),
        },
      );
      return (res.data ?? [])
          .map((e) => GareTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    });

class GareTransactionsPage extends ConsumerStatefulWidget {
  const GareTransactionsPage({super.key});

  @override
  ConsumerState<GareTransactionsPage> createState() =>
      _GareTransactionsPageState();
}

class _GareTransactionsPageState extends ConsumerState<GareTransactionsPage> {
  // Vue par défaut plus large que "Semaine" — voir partner_transactions_page.dart pour la
  // justification (filtre désormais sur la date du voyage, pas la date de réservation).
  PartnerPeriod _period = PartnerPeriod(
    mode: PartnerPeriodMode.custom,
    customFrom: DateTime.now().subtract(const Duration(days: 30)),
    customTo: DateTime.now().add(const Duration(days: 180)),
  );

  Future<void> _exportCsv(List<GareTransaction> transactions) async {
    final rows = [
      ['Référence', 'Trajet', 'Date résa', 'Date départ', 'Montant total FCFA', 'Statut'],
      ...transactions.map(
        (t) => [
          t.reference,
          t.route,
          DateFormat('dd/MM/yyyy HH:mm').format(t.date),
          t.departureDateTime != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(t.departureDateTime!)
              : '—',
          t.grossAmount.toStringAsFixed(0),
          t.status,
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/transactions_gare_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Transactions — Mobili');
  }

  Future<void> _exportPdf(List<GareTransaction> transactions) async {
    final pdf = pw.Document();
    final rows = [
      for (final t in transactions)
        [
          t.reference,
          t.route,
          DateFormat('dd/MM/yy HH:mm').format(t.date),
          t.departureDateTime != null
              ? DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime!)
              : '—',
          '${t.grossAmount.toStringAsFixed(0)} F',
          t.status,
        ],
    ];
    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            'Transactions',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: ['Référence', 'Trajet', 'Date résa', 'Date départ', 'Montant', 'Statut'],
            data: rows,
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
      '${dir.path}/transactions_gare_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Transactions — Mobili');
  }

  @override
  Widget build(BuildContext context) {
    final txnAsync = ref.watch(gareTransactionsRangeProvider(_period));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(gareTransactionsRangeProvider(_period)),
          ),
        ],
      ),
      body: Column(
        children: [
          PartnerPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          Expanded(
            child: txnAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (transactions) {
                final total = transactions.fold<double>(
                  0,
                  (s, t) => s + t.grossAmount,
                );

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async =>
                      ref.invalidate(gareTransactionsRangeProvider(_period)),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.payments_rounded,
                              color: AppColors.mobiliBlueDeep,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${total.toStringAsFixed(0)} F',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.mobiliBlueDeep,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Montant total',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (transactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Aucune transaction sur cette période',
                              style: TextStyle(color: AppColors.gray400),
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${transactions.length} transaction(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _exportCsv(transactions),
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
                                  onPressed: () => _exportPdf(transactions),
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
                        ...transactions.map((t) => _GareTransactionCard(t: t)),
                      ],
                    ],
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

class _GareTransactionCard extends StatelessWidget {
  const _GareTransactionCard({required this.t});
  final GareTransaction t;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(t.status);
    return Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                Text(
                  '${t.route} — Résa ${DateFormat('dd/MM/yy HH:mm').format(t.date)}'
                  '${t.departureDateTime != null ? ' · Départ ${DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime!)}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.gray500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${t.grossAmount.toStringAsFixed(0)} F',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.mobiliBlueDeep,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusConfig.$1,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(t.status),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusConfig.$2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Via Mobili';
      case 'OFFLINE_SALE':
        return 'Au guichet';
      default:
        return status;
    }
  }

  (Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return (const Color(0xFFD1FAE5), AppColors.stationGreen);
      case 'OFFLINE_SALE':
        return (AppColors.mobiliBlueFog, AppColors.mobiliBlue);
      default:
        return (AppColors.gray100, AppColors.gray500);
    }
  }
}
