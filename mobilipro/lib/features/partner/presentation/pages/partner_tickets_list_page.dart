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

class PartnerTicketItem {
  const PartnerTicketItem({
    required this.id,
    required this.ticketNumber,
    required this.passengerName,
    required this.route,
    required this.stationName,
    required this.bookingDate,
    required this.departureDateTime,
    required this.amountPaid,
    required this.status,
    required this.seatNumber,
    required this.scanned,
    required this.bookingStatus,
    this.grossAmount,
  });
  final int id;
  final String ticketNumber,
      passengerName,
      route,
      stationName,
      status,
      seatNumber;
  final DateTime bookingDate;
  /// Statut de la réservation d'origine (CONFIRMED/OFFLINE_SALE/...) — distingue vente en
  /// ligne / guichet, distinct du statut du ticket lui-même.
  final String? bookingStatus;
  /// Date de départ du voyage — distincte de bookingDate (date d'achat), voir
  /// GareTicketItem.departureDateTime (tickets_gare_page.dart).
  final DateTime? departureDateTime;

  /// Part du prix global (transport + forfait client + bagages) — jamais affiché côté
  /// partenaire (voir [displayAmount]), la compagnie n'a jamais reçu le forfait dilué ici.
  final double amountPaid;
  final bool scanned;

  /// Vente brute pour CE ticket (transport + bagages, jamais le forfait) — null sur les
  /// tickets antérieurs à la décomposition tarifaire.
  final double? grossAmount;

  /// Montant à afficher côté partenaire — JAMAIS amountPaid directement.
  double get displayAmount => grossAmount ?? amountPaid;

  factory PartnerTicketItem.fromJson(Map<String, dynamic> j) =>
      PartnerTicketItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        ticketNumber: j['ticketNumber'] as String? ?? '',
        passengerName: j['passengerName'] as String? ?? '',
        route: j['route'] as String? ?? '',
        stationName: j['stationName'] as String? ?? '—',
        bookingDate:
            DateTime.tryParse(j['bookingDate'] as String? ?? '') ??
            DateTime.now(),
        departureDateTime: DateTime.tryParse(
          j['departureDateTime'] as String? ?? '',
        ),
        amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
        grossAmount: (j['grossAmount'] as num?)?.toDouble(),
        status: j['status'] as String? ?? '',
        bookingStatus: j['bookingStatus'] as String?,
        seatNumber: j['seatNumber'] as String? ?? '',
        scanned: j['scanned'] as bool? ?? false,
      );
}

final partnerTicketsRangeProvider = FutureProvider.autoDispose
    .family<
      List<PartnerTicketItem>,
      ({PartnerPeriod period, int? stationId, String search})
    >((ref, args) async {
      final f = DateFormat('yyyy-MM-dd');
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/tickets/partner/my-tickets/range',
        queryParameters: {
          'fromDate': f.format(args.period.fromAsDate),
          'toDate': f.format(args.period.toAsDate),
          if (args.stationId != null) 'stationId': args.stationId,
          if (args.search.isNotEmpty) 'search': args.search,
        },
      );
      return (res.data ?? [])
          .map((e) => PartnerTicketItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

class PartnerTicketsListPage extends ConsumerStatefulWidget {
  const PartnerTicketsListPage({super.key});
  @override
  ConsumerState<PartnerTicketsListPage> createState() =>
      _PartnerTicketsListPageState();
}

/// Ticket "confirmé" = tout statut différent de ANNULÉ (VALIDÉ, UTILISÉ, ARRIVÉ).
/// Seuls ces tickets comptent dans les montants affichés — un ticket annulé ne doit
/// jamais gonfler les stats de vente du partenaire.
bool _isConfirmed(PartnerTicketItem t) => t.status.toUpperCase() != 'ANNULÉ';

class _PartnerTicketsListPageState
    extends ConsumerState<PartnerTicketsListPage> {
  PartnerPeriod _period = PartnerPeriod.week;
  int? _stationId;
  String _search = '';
  String _statusFilter = 'CONFIRME';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// La recherche texte est déjà appliquée côté serveur (voir partnerTicketsRangeProvider) —
  /// seul le statut se filtre côté client.
  List<PartnerTicketItem> _applyStatusFilter(List<PartnerTicketItem> tickets) {
    switch (_statusFilter) {
      case 'CONFIRME':
        return tickets.where(_isConfirmed).toList();
      case 'ANNULE':
        return tickets.where((t) => !_isConfirmed(t)).toList();
      default: // TOUS
        return tickets;
    }
  }

  Future<void> _exportCsv(List<PartnerTicketItem> tickets) async {
    final rows = [
      [
        'N° Ticket',
        'Passager',
        'Trajet',
        'Gare',
        'Date résa',
        'Date départ',
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
          t.stationName,
          DateFormat('dd/MM/yyyy HH:mm').format(t.bookingDate),
          t.departureDateTime != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(t.departureDateTime!)
              : '—',
          t.displayAmount.toStringAsFixed(0),
          t.status,
          t.seatNumber,
          t.scanned ? 'Oui' : 'Non',
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/mes_tickets_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Mes tickets — Mobili');
  }

  Future<void> _exportPdf(List<PartnerTicketItem> tickets) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            'Mes tickets vendus',
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
              'Gare',
              'Date résa',
              'Date départ',
              'Montant',
              'Statut',
            ],
            data: tickets
                .map(
                  (t) => [
                    t.ticketNumber,
                    t.passengerName,
                    t.route,
                    t.stationName,
                    DateFormat('dd/MM/yy HH:mm').format(t.bookingDate),
                    t.departureDateTime != null
                        ? DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime!)
                        : '—',
                    '${t.displayAmount.toStringAsFixed(0)} F',
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
      '${dir.path}/mes_tickets_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Mes tickets — Mobili');
  }

  @override
  Widget build(BuildContext context) {
  final ticketsAsync = ref.watch(
      partnerTicketsRangeProvider((
        period: _period,
        stationId: _stationId,
        search: _search,
      )),
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
          PartnerPeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
        PartnerStationFilter(
            selectedStationId: _stationId,
            onChanged: (id) => setState(() => _stationId = id),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _StatusFilterChip(
                  label: 'Confirmé',
                  selected: _statusFilter == 'CONFIRME',
                  onTap: () => setState(() => _statusFilter = 'CONFIRME'),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Annulé',
                  selected: _statusFilter == 'ANNULE',
                  onTap: () => setState(() => _statusFilter = 'ANNULE'),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Tous',
                  selected: _statusFilter == 'TOUS',
                  onTap: () => setState(() => _statusFilter = 'TOUS'),
                ),
              ],
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
              data: (allTickets) {
                final tickets = _applyStatusFilter(allTickets);
                // Montant confirmé — jamais influencé par le filtre de statut affiché.
                final confirmedAmount = allTickets
                    .where(_isConfirmed)
                    .fold<double>(0, (s, t) => s + t.displayAmount);
                if (tickets.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun ticket sur cette période',
                      style: TextStyle(color: AppColors.gray400),
                    ),
                  );
                }
                return ListView(
                      padding: const EdgeInsets.all(16),
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
                                        '${t.stationName} — Résa ${DateFormat('dd/MM/yy HH:mm').format(t.bookingDate)}'
                                        '${t.departureDateTime != null ? ' · Départ ${DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime!)}' : ''}',
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
                                    Text(
                                      '${t.displayAmount.toStringAsFixed(0)} F',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: AppColors.proGold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _TicketStatusBadge(status: t.status),
                                  ],
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

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.mobiliBlue : AppColors.gray100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.white : AppColors.gray600,
        ),
      ),
    ),
  );
}

class _TicketStatusBadge extends StatelessWidget {
  const _TicketStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isCancelled = status.toUpperCase() == 'ANNULÉ';
    final color = isCancelled ? AppColors.danger : AppColors.stationGreen;
    final bg = isCancelled ? AppColors.dangerSoft : const Color(0xFFD1FAE5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        isCancelled ? 'Annulé' : 'Confirmé',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
