import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/partner_period_selector.dart';
import '../widgets/partner_station_filter.dart';
import '../../../admin/presentation/widgets/admin_common_widgets.dart';

/// Une ligne = une réservation payée. Ne contient JAMAIS le forfait de service Mobili — ce
/// montant n'a jamais appartenu à la compagnie (voir PartnerTransactionResponse côté backend).
class PartnerTransaction {
  const PartnerTransaction({
    required this.bookingId,
    required this.reference,
    required this.date,
    required this.departureDateTime,
    required this.route,
    required this.stationName,
    required this.grossAmount,
    required this.commissionTotal,
    required this.companyNet,
    required this.status,
  });

  final int bookingId, commissionTotal;
  final String reference, route, stationName, status;
  final DateTime date;
  /// Date de départ du voyage — distincte de date (date de réservation), voir
  /// GareTicketItem.departureDateTime (tickets_gare_page.dart).
  final DateTime? departureDateTime;
  final double grossAmount, companyNet;

  factory PartnerTransaction.fromJson(Map<String, dynamic> j) => PartnerTransaction(
        bookingId: (j['bookingId'] as num?)?.toInt() ?? 0,
        reference: j['reference'] as String? ?? '',
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        departureDateTime: DateTime.tryParse(
          j['departureDateTime'] as String? ?? '',
        ),
        route: j['route'] as String? ?? '',
        stationName: j['stationName'] as String? ?? '—',
        grossAmount: (j['grossAmount'] as num?)?.toDouble() ?? 0,
        commissionTotal: (j['commissionTotal'] as num?)?.toInt() ?? 0,
        companyNet: (j['companyNet'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
      );
}

final partnerTransactionsRangeProvider = FutureProvider.autoDispose
    .family<List<PartnerTransaction>, ({PartnerPeriod period, int? stationId})>(
      (ref, args) async {
        final f = DateFormat('yyyy-MM-dd');
        final res = await ApiClient.instance.dio.get<List<dynamic>>(
          '/bookings/partner/transactions/range',
          queryParameters: {
            'fromDate': f.format(args.period.fromAsDate),
            'toDate': f.format(args.period.toAsDate),
            if (args.stationId != null) 'stationId': args.stationId,
          },
        );
        return (res.data ?? [])
            .map((e) => PartnerTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );

class PartnerTransactionsPage extends ConsumerStatefulWidget {
  const PartnerTransactionsPage({super.key});

  @override
  ConsumerState<PartnerTransactionsPage> createState() =>
      _PartnerTransactionsPageState();
}

class _PartnerTransactionsPageState
    extends ConsumerState<PartnerTransactionsPage> {
  // Vue par défaut plus large que "Semaine" : la période filtre désormais sur la date du
  // VOYAGE (pas la date de réservation), donc une résa faite aujourd'hui pour un trajet la
  // semaine/le mois prochain n'apparaissait plus du tout — on couvre large (30 j en arrière,
  // 180 j en avant) pour que les réservations récentes restent visibles avec leur commission.
  PartnerPeriod _period = PartnerPeriod(
    mode: PartnerPeriodMode.custom,
    customFrom: DateTime.now().subtract(const Duration(days: 30)),
    customTo: DateTime.now().add(const Duration(days: 180)),
  );
  int? _stationId;
  int _pageSize = 20;

  Future<void> _exportCsv(List<PartnerTransaction> transactions) async {
    final rows = [
      ['Référence', 'Trajet', 'Gare', 'Date résa', 'Date départ', 'Vente brute FCFA', 'Commission FCFA', 'Net FCFA', 'Statut'],
      ...transactions.map(
        (t) => [
          t.reference,
          t.route,
          t.stationName,
          DateFormat('dd/MM/yyyy HH:mm').format(t.date),
          t.departureDateTime != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(t.departureDateTime!)
              : '—',
          t.grossAmount.toStringAsFixed(0),
          '${t.commissionTotal}',
          t.companyNet.toStringAsFixed(0),
          t.status,
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Transactions — Mobili');
  }

  @override
  Widget build(BuildContext context) {
    final txnAsync = ref.watch(
      partnerTransactionsRangeProvider((period: _period, stationId: _stationId)),
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          PartnerPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() {
              _period = p;
              _pageSize = 20;
            }),
          ),
          PartnerStationFilter(
            selectedStationId: _stationId,
            onChanged: (id) => setState(() {
              _stationId = id;
              _pageSize = 20;
            }),
          ),
          Expanded(
            child: txnAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text('Erreur : $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (transactions) {
                final totalGross =
                    transactions.fold<double>(0, (s, t) => s + t.grossAmount);
                final totalCommission =
                    transactions.fold<int>(0, (s, t) => s + t.commissionTotal);
                final totalNet =
                    transactions.fold<double>(0, (s, t) => s + t.companyNet);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _TxnStatCard(
                            icon: Icons.payments_rounded,
                            label: 'Vente brute',
                            value: '${totalGross.toStringAsFixed(0)} F',
                            color: AppColors.mobiliBlueDeep,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TxnStatCard(
                            icon: Icons.percent_rounded,
                            label: 'Commission',
                            value: '$totalCommission F',
                            color: AppColors.proGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TxnStatCard(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Net à recevoir',
                      value: '${totalNet.toStringAsFixed(0)} F',
                      color: AppColors.stationGreen,
                      fullWidth: true,
                    ),
                    const SizedBox(height: 10),
                    // Évite tout malentendu : le forfait passager n'a jamais transité par
                    // la compagnie, donc pas de raison de le voir soustrait ici.
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.mobiliBlueFog,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.mobiliBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Le forfait de service Mobili payé par le passager n'est jamais déduit de vos ventes.",
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.mobiliBlueDeep),
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
                    else ...(() {
                      final visible = transactions.take(_pageSize).toList();
                      final hasMore = transactions.length > _pageSize;

                      // Regroupement par jour : un en-tête de date suivi des cartes du jour.
                      final grouped = <Widget>[];
                      DateTime? lastDay;
                      for (final t in visible) {
                        final day = DateTime(t.date.year, t.date.month, t.date.day);
                        if (lastDay == null || day != lastDay) {
                          grouped.add(_DateGroupHeader(date: day));
                          lastDay = day;
                        }
                        grouped.add(_TransactionCard(t: t));
                      }

                      return [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${visible.length} / ${transactions.length} transaction(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _exportCsv(transactions),
                              icon: const Icon(Icons.table_chart_rounded, size: 15),
                              label: const Text('CSV', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...grouped,
                        if (hasMore)
                          LoadMoreButton(
                            remaining: transactions.length - _pageSize,
                            onTap: () => setState(() => _pageSize += 20),
                          ),
                      ];
                    })(),
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

/// En-tête de regroupement par jour dans la liste des transactions.
class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.mobiliBlueDeep,
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.t});
  final PartnerTransaction t;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      '${t.route} (${t.stationName}) — Résa ${DateFormat('dd/MM/yy HH:mm').format(t.date)}'
                      '${t.departureDateTime != null ? ' · Départ ${DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime!)}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.gray500),
                    ),
                  ],
                ),
              ),
              Text(
                '${t.grossAmount.toStringAsFixed(0)} F',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.mobiliBlueDeep,
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.gray100),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountTag(
                  label: 'Commission', value: '${t.commissionTotal} F', color: AppColors.proGold),
              _AmountTag(
                  label: 'Net à recevoir',
                  value: '${t.companyNet.toStringAsFixed(0)} F',
                  color: AppColors.stationGreen),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountTag extends StatelessWidget {
  const _AmountTag({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.gray400)),
        Text(value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _TxnStatCard extends StatelessWidget {
  const _TxnStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray200),
        ),
        child: fullWidth
            ? Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 10),
                  Text(value,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: AppColors.gray500)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 8),
                  Text(value,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: AppColors.gray500)),
                ],
              ),
      );
}
