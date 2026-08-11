import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_export_helpers.dart';
import '../widgets/admin_period_selector.dart';

/// Décomposition des transactions payées : frais Mobili (forfait client, jamais reversé),
/// commission prélevée sur chaque compagnie, et net qui revient réellement à la compagnie.
/// Même structure que TicketStatsDetailPage — pas de stats agrégées côté serveur ici, les
/// totaux du header sont calculés côté client sur la liste déjà récupérée (même principe que
/// les autres pages stats, qui font déjà une partie de leur agrégation en Dart).
class AdminTransactionsPage extends ConsumerStatefulWidget {
  const AdminTransactionsPage({super.key});
  @override
  ConsumerState<AdminTransactionsPage> createState() =>
      _AdminTransactionsPageState();
}

class _AdminTransactionsPageState
    extends ConsumerState<AdminTransactionsPage> {
  AdminStatsPeriod _period = kPeriodMonth;
  String _search = '';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(
      transactionListProvider((period: _period, search: _search)),
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
          AdminPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() {
              _period = p;
              _pageSize = 20;
            }),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (list) {
                final totalServiceFee =
                    list.fold<int>(0, (sum, t) => sum + t.serviceFee);
                final totalCommission =
                    list.fold<int>(0, (sum, t) => sum + t.commissionTotal);
                final totalCompanyNet =
                    list.fold<double>(0, (sum, t) => sum + t.companyNet);
                final totalRevenue =
                    list.fold<double>(0, (sum, t) => sum + t.totalPrice);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: KpiCard(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Frais Mobili',
                            value: '$totalServiceFee F',
                            color: AppColors.mobiliBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: KpiCard(
                            icon: Icons.percent_rounded,
                            label: 'Commission',
                            value: '$totalCommission F',
                            color: AppColors.proGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: KpiCard(
                            icon: Icons.business_rounded,
                            label: 'Net compagnies',
                            value: '${totalCompanyNet.toStringAsFixed(0)} F',
                            color: AppColors.stationGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: KpiCard(
                            icon: Icons.payments_rounded,
                            label: 'CA total',
                            value: '${totalRevenue.toStringAsFixed(0)} F',
                            color: AppColors.mobiliBlueDeep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Liste des transactions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.mobiliBlueDeep,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() {
                        _search = v;
                        _pageSize = 20;
                      }),
                      decoration: InputDecoration(
                        hintText: 'Rechercher référence, client, compagnie...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.gray200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Aucune transaction trouvée',
                            style: TextStyle(color: AppColors.gray400),
                          ),
                        ),
                      )
                    else
                      Builder(builder: (context) {
                        final visible = list.take(_pageSize).toList();
                        final hasMore = list.length > _pageSize;
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${visible.length} / ${list.length} transaction(s)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      exportTransactionsCsv(list, context),
                                  icon: const Icon(Icons.table_chart_rounded,
                                      size: 15),
                                  label: const Text('CSV',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...visible.map((t) => _TransactionCard(t: t)),
                            if (hasMore)
                              LoadMoreButton(
                                remaining: list.length - _pageSize,
                                onTap: () =>
                                    setState(() => _pageSize += 20),
                              ),
                          ],
                        );
                      }),
                    const SizedBox(height: 32),
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

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.t});
  final AdminTransaction t;

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
                      '${t.customerName} — ${t.route}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.gray500),
                    ),
                    Text(
                      '${t.companyName} · ${DateFormat('dd/MM/yy HH:mm').format(t.date)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.gray400),
                    ),
                  ],
                ),
              ),
              Text(
                '${t.totalPrice.toStringAsFixed(0)} F',
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
              _AmountTag(label: 'Frais Mobili', value: '${t.serviceFee} F', color: AppColors.mobiliBlue),
              _AmountTag(label: 'Commission', value: '${t.commissionTotal} F', color: AppColors.proGold),
              _AmountTag(
                  label: 'Net compagnie',
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
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppColors.gray400)),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
