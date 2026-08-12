import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_filter_chip.dart';
import '../models/admin_stats_models.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/admin_export_helpers.dart';
import '../widgets/admin_period_selector.dart';

/// Ticket "confirmé" = tout statut différent de ANNULÉ (VALIDÉ, UTILISÉ, ARRIVÉ).
/// Seuls ces tickets comptent dans le montant affiché — un ticket annulé ne doit
/// jamais gonfler les stats de vente.
bool _isConfirmedTicket(AdminTicketListItem t) =>
    t.status.toUpperCase() != 'ANNULÉ';

class TicketStatsDetailPage extends ConsumerStatefulWidget {
  const TicketStatsDetailPage({super.key});
  @override
  ConsumerState<TicketStatsDetailPage> createState() =>
      _TicketStatsDetailPageState();
}

class _TicketStatsDetailPageState extends ConsumerState<TicketStatsDetailPage> {
  AdminStatsPeriod _period = kPeriodMonth;
  String _search = '';
  String _statusFilter = 'CONFIRME';
  int _pageSize = 20;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminTicketListItem> _applyStatusFilter(List<AdminTicketListItem> tickets) =>
      _statusFilter == 'CONFIRME'
          ? tickets.where(_isConfirmedTicket).toList()
          : tickets.where((t) => !_isConfirmedTicket(t)).toList();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketStatsProvider(_period));
    final listAsync = ref.watch(
      ticketListProvider((period: _period, search: _search)),
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Tickets vendus',
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
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (stats) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: KpiCard(
                          icon: Icons.confirmation_number_rounded,
                          label: "Aujourd'hui",
                          value: '${stats.todayTickets}',
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiCard(
                          icon: Icons.receipt_long_rounded,
                          label: 'Total',
                          value: '${stats.totalTickets}',
                          color: AppColors.stationGreen,
                        ),
                      ),
                    ],
                  ),
                  if (stats.history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ChartCard(
                      title: 'Historique — ${_period.label()}',
                      child: SizedBox(
                        height: 200,
                        child: AdminLineChartWidget(
                          entries: stats.history,
                          getValue: (e) =>
                              (e as RegistrationDayEntry).count.toDouble(),
                          getDate: (e) => (e as RegistrationDayEntry).date,
                          color: AppColors.mobiliBlue,
                          showTooltip: true,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Liste des tickets',
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
                      hintText: 'Rechercher n° ticket ou passager...',
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
                  Row(
                    children: [
                      StatusFilterChip(
                        label: 'Confirmé',
                        selected: _statusFilter == 'CONFIRME',
                        onTap: () => setState(() {
                          _statusFilter = 'CONFIRME';
                          _pageSize = 20;
                        }),
                      ),
                      const SizedBox(width: 8),
                      StatusFilterChip(
                        label: 'Annulé',
                        selected: _statusFilter == 'ANNULE',
                        onTap: () => setState(() {
                          _statusFilter = 'ANNULE';
                          _pageSize = 20;
                        }),
                      ),
                    ],
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
                      'Erreur liste : $e',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    data: (allTickets) {
                      final list = _applyStatusFilter(allTickets);
                      // Montant confirmé — jamais influencé par le filtre affiché.
                      final confirmedAmount = allTickets
                          .where(_isConfirmedTicket)
                          .fold<double>(0, (s, t) => s + t.amountPaid);
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Aucun ticket trouvé',
                              style: TextStyle(color: AppColors.gray400),
                            ),
                          ),
                        );
                      }
                      final visible = list.take(_pageSize).toList();
                      final hasMore = list.length > _pageSize;
                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.payments_rounded,
                                  color: AppColors.stationGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${confirmedAmount.toStringAsFixed(0)} F',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.mobiliBlueDeep,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'confirmé',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${visible.length} / ${list.length} ticket(s)',
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
                                        exportTicketsCsv(list, context),
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
                                        exportTicketsPdf(list, context),
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
          ),
        ],
      ),
    );
  }
}
