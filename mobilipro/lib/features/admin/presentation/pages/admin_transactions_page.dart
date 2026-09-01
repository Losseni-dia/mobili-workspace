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
  // Vue par défaut plus large que "Mois" — voir partner_transactions_page.dart (mobilipro)
  // pour la justification (filtre désormais sur la date du voyage, pas la date de réservation).
  // `days` seul ne couvre que le passé (voir toQueryParams) : il faut fromDate/toDate explicites
  // pour englober aussi les voyages à venir.
  AdminStatsPeriod _period = (
    days: 0,
    fromDate: DateTime.now().subtract(const Duration(days: 30)),
    toDate: DateTime.now().add(const Duration(days: 180)),
  );
  String _search = '';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();
  // Filtre société, puis gare (dépendante de la société sélectionnée).
  int? _companyId;
  int? _stationId;

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
              _companyId = null;
              _stationId = null;
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
                // Sociétés/gares présentes dans la période chargée — filtrage 100% client,
                // pas de nouvel appel réseau (aligné sur admin-transactions web).
                final companies = <int, String>{};
                for (final t in list) {
                  if (t.companyId != null) companies[t.companyId!] = t.companyName;
                }
                final companyEntries = companies.entries.toList()
                  ..sort((a, b) => a.value.compareTo(b.value));

                final stations = <int, String>{};
                if (_companyId != null) {
                  for (final t in list) {
                    if (t.companyId == _companyId && t.stationId != null) {
                      stations[t.stationId!] = t.stationName;
                    }
                  }
                }
                final stationEntries = stations.entries.toList()
                  ..sort((a, b) => a.value.compareTo(b.value));

                final filteredList = list.where((t) {
                  final matchCompany = _companyId == null || t.companyId == _companyId;
                  final matchStation = _stationId == null || t.stationId == _stationId;
                  return matchCompany && matchStation;
                }).toList();

                final totalServiceFee =
                    filteredList.fold<int>(0, (sum, t) => sum + t.serviceFee);
                final totalCommission =
                    filteredList.fold<int>(0, (sum, t) => sum + t.commissionTotal);
                final totalCompanyNet =
                    filteredList.fold<double>(0, (sum, t) => sum + t.companyNet);
                final totalRevenue =
                    filteredList.fold<double>(0, (sum, t) => sum + t.totalPrice);

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
                    Row(
                      children: [
                        Expanded(
                          child: _FilterDropdown<int>(
                            icon: Icons.business_rounded,
                            hint: 'Toutes les sociétés',
                            value: _companyId,
                            items: companyEntries
                                .map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _companyId = v;
                              // La gare dépend de la société — un choix précédent n'a plus
                              // de sens si on change de société.
                              _stationId = null;
                              _pageSize = 20;
                            }),
                          ),
                        ),
                        if (_companyId != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _FilterDropdown<int>(
                              icon: Icons.location_city_rounded,
                              hint: 'Toutes les gares',
                              value: _stationId,
                              items: stationEntries
                                  .map((e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _stationId = v;
                                _pageSize = 20;
                              }),
                            ),
                          ),
                        ],
                      ],
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
                    if (filteredList.isEmpty)
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
                        final visible = filteredList.take(_pageSize).toList();
                        final hasMore = filteredList.length > _pageSize;

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

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${visible.length} / ${filteredList.length} transaction(s)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      exportTransactionsCsv(filteredList, context),
                                  icon: const Icon(Icons.table_chart_rounded,
                                      size: 15),
                                  label: const Text('CSV',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...grouped,
                            if (hasMore)
                              LoadMoreButton(
                                remaining: filteredList.length - _pageSize,
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

/// Sélecteur filtre (société/gare) — style aligné sur le TextField de recherche au-dessus.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          hint: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.gray400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(hint,
                    style: const TextStyle(fontSize: 12, color: AppColors.gray400),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 12, color: AppColors.mobiliBlueDeep),
          items: items,
          onChanged: onChanged,
        ),
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
                      '${t.customerName} — ${t.route} (${t.stationName})',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.gray500),
                    ),
                    Text(
                      '${t.companyName} · Résa ${DateFormat('dd/MM/yy HH:mm').format(t.date)}'
                      '${t.departureDateTime != null ? ' · Départ ${DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime!)}' : ''}',
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
