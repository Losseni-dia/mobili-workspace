import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/features/trips/presentation/pages/trips_gare_page.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle ligne passager (une ligne = un passager individuel)
// ─────────────────────────────────────────────────────────────────────────────

class PassengerLine {
  const PassengerLine({
    required this.passengerName,
    required this.seatNumber,
    required this.reference,
    required this.bookingId,
    required this.status,
    required this.amount,
    required this.boardingCity,
    required this.alightingCity,
  });

  final String passengerName;
  final String seatNumber;
  final String reference;
  final int bookingId;
  final String status;
  final double amount;
  final String boardingCity;
  final String alightingCity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final _passengersLinesProvider = FutureProvider.autoDispose
    .family<List<PassengerLine>, int>((ref, tripId) async {
      final dio = ApiClient.instance.dio;
      final response = await dio.get<List<dynamic>>(
        '/bookings/trips/$tripId/passengers',
      );

      final lines = <PassengerLine>[];
      for (final e in response.data ?? []) {
        final json = e as Map<String, dynamic>;
        final reference = json['reference'] as String? ?? '';
        final bookingId = json['id'] as int;
        final status = json['status'] as String? ?? '';
        final amount = (json['amount'] as num?)?.toDouble() ?? 0;
        final boardingCity = json['boardingCity'] as String? ?? '';
        final alightingCity = json['alightingCity'] as String? ?? '';

        final passengerNames = (json['passengerNames'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList();
        final seatNumbers = (json['seatNumbers'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList();

        // Une ligne par passager
        for (int i = 0; i < passengerNames.length; i++) {
          lines.add(
            PassengerLine(
              passengerName: passengerNames[i],
              seatNumber: i < seatNumbers.length ? seatNumbers[i] : '—',
              reference: reference,
              bookingId: bookingId,
              status: status,
              amount:
                  amount /
                  (passengerNames.isNotEmpty ? passengerNames.length : 1),
              boardingCity: boardingCity,
              alightingCity: alightingCity,
            ),
          );
        }
      }
      return lines;
    });

// ─────────────────────────────────────────────────────────────────────────────
// Sheet passagers
// ─────────────────────────────────────────────────────────────────────────────

class PassengersSheet extends ConsumerStatefulWidget {
  const PassengersSheet({super.key, required this.trip});
  final TripItem trip;

  @override
  ConsumerState<PassengersSheet> createState() => _PassengersSheetState();
}

class _PassengersSheetState extends ConsumerState<PassengersSheet> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linesAsync = ref.watch(_passengersLinesProvider(widget.trip.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Passagers',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mobiliBlueDeep,
                        ),
                      ),
                      Text(
                        '${widget.trip.departureCity} → ${widget.trip.arrivalCity}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.gray400,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),

          // Barre recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gray200),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Nom passager ou n° réservation...',
                  hintStyle: const TextStyle(
                    color: AppColors.gray400,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.gray400,
                    size: 18,
                  ),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: 16,
                            color: AppColors.gray400,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.gray100),

          // Liste
          Expanded(
            child: linesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (lines) {
                // Filtre recherche
                var filtered = lines.where((l) {
                  if (_search.isEmpty) return true;
                  final q = _search.toLowerCase();
                  return l.passengerName.toLowerCase().contains(q) ||
                      l.reference.toLowerCase().contains(q) ||
                      l.seatNumber.toLowerCase().contains(q);
                }).toList();

                if (lines.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: AppColors.gray300,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Aucun passager confirmé',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: AppColors.gray300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun résultat pour "$_search"',
                          style: const TextStyle(
                            color: AppColors.gray400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Stats
                final totalPassengers = filtered.length;
                final totalRevenue = filtered.fold(0.0, (s, l) => s + l.amount);

                return Column(
                  children: [
                    // Stats banner
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mobiliBlueFog,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MiniStat(
                            label: 'Passagers',
                            value: '$totalPassengers',
                            color: AppColors.mobiliBlue,
                          ),
                          _MiniStat(
                            label: 'Revenus',
                            value:
                                NumberFormat('#,###').format(totalRevenue) +
                                ' F',
                            color: AppColors.proGold,
                          ),
                          _MiniStat(
                            label: 'Libres',
                            value: '${widget.trip.availableSeats}',
                            color: AppColors.stationGreen,
                          ),
                        ],
                      ),
                    ),

                    // Liste passagers
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _PassengerLineCard(
                          line: filtered[i],
                          search: _search,
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

// ─────────────────────────────────────────────────────────────────────────────
// Carte ligne passager
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerLineCard extends StatelessWidget {
  const _PassengerLineCard({required this.line, required this.search});
  final PassengerLine line;
  final String search;

  @override
  Widget build(BuildContext context) {
    final isOffline = line.status == 'OFFLINE_SALE';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOffline
              ? AppColors.mobiliBlue.withValues(alpha: 0.3)
              : AppColors.gray200,
        ),
      ),
      child: Row(
        children: [
          // Avatar initial
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isOffline
                  ? AppColors.mobiliBlueFog
                  : const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                line.passengerName.isNotEmpty
                    ? line.passengerName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isOffline
                      ? AppColors.mobiliBlue
                      : AppColors.stationGreen,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom passager avec highlight si recherche
                _HighlightText(
                  text: line.passengerName,
                  highlight: search,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                const SizedBox(height: 2),
                // Tronçon
                if (line.boardingCity.isNotEmpty)
                  Text(
                    '${line.boardingCity} → ${line.alightingCity}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mobiliBlue,
                    ),
                  ),
                const SizedBox(height: 2),
                // Référence avec highlight
                _HighlightText(
                  text: line.reference,
                  highlight: search,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),

          // Siège + statut
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mobiliBlueDeep,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Siège ${line.seatNumber}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isOffline
                      ? AppColors.mobiliBlueFog
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOffline ? 'Au guichet' : 'Via Mobili',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isOffline
                        ? AppColors.mobiliBlue
                        : AppColors.stationGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Highlight texte recherche
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  const _HighlightText({
    required this.text,
    required this.highlight,
    required this.style,
  });
  final String text;
  final String highlight;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) {
      return Text(text, style: style);
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(highlight.toLowerCase());
    if (idx < 0) return Text(text, style: style);

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + highlight.length),
            style: style.copyWith(
              backgroundColor: AppColors.mobiliYellow.withValues(alpha: 0.4),
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: text.substring(idx + highlight.length)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: color,
          fontSize: 16,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.gray500),
      ),
    ],
  );
}
