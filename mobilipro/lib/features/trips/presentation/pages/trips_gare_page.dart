import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/search_filter_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────

class TripItem {
  const TripItem({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.boardingPoint,
    required this.departureDateTime,
    required this.price,
    required this.totalSeats,
    required this.availableSeats,
    required this.status,
    required this.vehicleType,
    required this.vehiculePlateNumber,
    this.vehicleImageUrl,
    this.moreInfo,
    this.assignedChauffeurFirstname,
    this.assignedChauffeurLastname,
    this.stationName,
  });

  final int id;
  final String departureCity;
  final String arrivalCity;
  final String boardingPoint;
  final DateTime departureDateTime;
  final double price;
  final int totalSeats;
  final int availableSeats;
  final String status;
  final String vehicleType;
  final String vehiculePlateNumber;
  final String? vehicleImageUrl;
  final String? moreInfo;
  final String? assignedChauffeurFirstname;
  final String? assignedChauffeurLastname;
  final String? stationName;

  String get chauffeurName {
    if (assignedChauffeurFirstname == null) return 'Non assigné';
    return '$assignedChauffeurFirstname $assignedChauffeurLastname'.trim();
  }

  bool get hasChauffeur => assignedChauffeurFirstname != null;

  int get occupancyRate =>
      totalSeats > 0 ? ((totalSeats - availableSeats) * 100 ~/ totalSeats) : 0;

  factory TripItem.fromJson(Map<String, dynamic> json) => TripItem(
    id: json['id'] as int,
    departureCity: json['departureCity'] as String? ?? '',
    arrivalCity: json['arrivalCity'] as String? ?? '',
    boardingPoint: json['boardingPoint'] as String? ?? '',
    departureDateTime:
        DateTime.tryParse(json['departureDateTime'] as String? ?? '') ??
        DateTime.now(),
    price: (json['price'] as num?)?.toDouble() ?? 0,
    totalSeats: (json['totalSeats'] as num?)?.toInt() ?? 0,
    availableSeats: (json['availableSeats'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? '',
    vehicleType: json['vehicleType'] as String? ?? '',
    vehiculePlateNumber: json['vehiculePlateNumber'] as String? ?? '',
    vehicleImageUrl: json['vehicleImageUrl'] as String?,
    moreInfo: json['moreInfo'] as String?,
    assignedChauffeurFirstname: json['assignedChauffeurFirstname'] as String?,
    assignedChauffeurLastname: json['assignedChauffeurLastname'] as String?,
    stationName: json['stationName'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final _myTripsProvider = FutureProvider.autoDispose<List<TripItem>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<List<dynamic>>('/trips/my-trips');
  return (response.data ?? [])
      .map((e) => TripItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// Constantes filtres
// ─────────────────────────────────────────────────────────────────────────────

const _tripFilterItems = [
  FilterItem(value: 'TOUS', label: 'Tous'),
  FilterItem(value: 'PROGRAMMÉ', label: 'Programmé'),
  FilterItem(value: 'EN_COURS', label: 'En cours'),
  FilterItem(value: 'TERMINÉ', label: 'Terminé'),
  FilterItem(value: 'ANNULÉ', label: 'Annulé'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class TripsGarePage extends ConsumerStatefulWidget {
  const TripsGarePage({super.key});

  @override
  ConsumerState<TripsGarePage> createState() => _TripsGarePageState();
}

class _TripsGarePageState extends ConsumerState<TripsGarePage> {
  String _filter = 'TOUS';
  String _search = '';
  final Set<int> _archivedIds = {};
  bool _showArchived = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(_myTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mes trajets',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_archivedIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _showArchived = !_showArchived),
              child: Text(
                _showArchived ? 'Masquer archivés' : 'Voir archivés',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_myTripsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/gare/trips/create');
          if (result == true) ref.invalidate(_myTripsProvider);
        },
        backgroundColor: AppColors.mobiliBlue,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(
          'Nouveau trajet',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // SearchFilterBar réutilisable
          SearchFilterBar(
            hintText: 'Rechercher un trajet...',
            filterValue: _filter,
            filterItems: _tripFilterItems,
            controller: _searchCtrl,
            onSearchChanged: (v) => setState(() => _search = v),
            onFilterChanged: (v) => setState(() => _filter = v),
          ),

          Expanded(
            child: tripsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Erreur : $e',
                      style: const TextStyle(color: AppColors.gray500),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_myTripsProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (trips) {
                var filtered = trips.where((t) {
                  if (_archivedIds.contains(t.id)) {
                    return _showArchived;
                  }
                  if (_filter != 'TOUS' && t.status != _filter) return false;
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    return t.departureCity.toLowerCase().contains(q) ||
                        t.arrivalCity.toLowerCase().contains(q) ||
                        t.vehiculePlateNumber.toLowerCase().contains(q);
                  }
                  return true;
                }).toList();

                filtered.sort(
                  (a, b) => b.departureDateTime.compareTo(a.departureDateTime),
                );

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.mobiliBlueFog,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.directions_bus_rounded,
                            color: AppColors.mobiliBlue,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Aucun trajet trouvé',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.mobiliBlueDeep,
                            fontSize: 16,
                          ),
                        ),
                        if (_archivedIds.isNotEmpty && !_showArchived) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_archivedIds.length} trajet(s) masqué(s)',
                            style: const TextStyle(
                              color: AppColors.gray400,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showArchived = true),
                            child: const Text('Afficher les masqués'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async => ref.invalidate(_myTripsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final trip = filtered[index];
                      final isArchived = _archivedIds.contains(trip.id);
                      return _TripCard(
                        trip: trip,
                        isArchived: isArchived,
                        onArchive: () => setState(() {
                          if (isArchived) {
                            _archivedIds.remove(trip.id);
                          } else {
                            _archivedIds.add(trip.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Trajet masqué'),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'Annuler',
                                  onPressed: () => setState(
                                    () => _archivedIds.remove(trip.id),
                                  ),
                                ),
                              ),
                            );
                          }
                        }),
                      );
                    },
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

// ─────────────────────────────────────────────────────────────────────────────
// Carte trajet
// ─────────────────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onArchive,
    required this.isArchived,
  });
  final TripItem trip;
  final VoidCallback onArchive;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _statusConfig(trip.status);

    return Opacity(
      opacity: isArchived ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray200),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isArchived
                      ? [AppColors.gray400, AppColors.gray500]
                      : [const Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trip.departureCity,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.mobiliYellow,
                                size: 14,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                trip.arrivalCity,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: AppColors.mobiliYellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy à HH:mm',
                              ).format(trip.departureDateTime),
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusConfig.$1,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          trip.status,
                          style: TextStyle(
                            color: statusConfig.$2,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isArchived) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Masqué',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Infos
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.directions_bus_rounded,
                          label: trip.vehicleType.replaceAll('_', ' '),
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.confirmation_number_rounded,
                          label: trip.vehiculePlateNumber,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.event_seat_rounded,
                          label:
                              '${trip.availableSeats}/${trip.totalSeats} places',
                          color: trip.availableSeats <= 5
                              ? AppColors.danger
                              : AppColors.stationGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.payments_rounded,
                          label:
                              NumberFormat('#,###').format(trip.price) +
                              ' FCFA',
                          color: AppColors.proGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Taux de remplissage',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gray400,
                            ),
                          ),
                          Text(
                            '${trip.occupancyRate}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: trip.occupancyRate >= 80
                                  ? AppColors.stationGreen
                                  : trip.occupancyRate >= 50
                                  ? AppColors.warning
                                  : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: trip.occupancyRate / 100,
                          backgroundColor: AppColors.gray100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            trip.occupancyRate >= 80
                                ? AppColors.stationGreen
                                : trip.occupancyRate >= 50
                                ? AppColors.warning
                                : AppColors.danger,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        trip.hasChauffeur
                            ? Icons.person_rounded
                            : Icons.person_off_rounded,
                        size: 14,
                        color: trip.hasChauffeur
                            ? AppColors.stationGreen
                            : AppColors.gray400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trip.chauffeurName,
                          style: TextStyle(
                            fontSize: 12,
                            color: trip.hasChauffeur
                                ? AppColors.stationGreen
                                : AppColors.gray400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (trip.stationName != null) ...[
                        const Icon(
                          Icons.store_rounded,
                          size: 13,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trip.stationName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            const Divider(height: 1, color: AppColors.gray100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                     onPressed: () => context.push(
                        '/gare/trips/canal/${trip.id}?label=${Uri.encodeComponent('${trip.departureCity} → ${trip.arrivalCity}')}',
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                      label: const Text(
                        'Canal',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mobiliBlue,
                        side: const BorderSide(color: AppColors.mobiliBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text(
                        'Modifier',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gray600,
                        side: const BorderSide(color: AppColors.gray300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onArchive,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isArchived
                          ? AppColors.stationGreen
                          : AppColors.gray400,
                      side: BorderSide(
                        color: isArchived
                            ? AppColors.stationGreen
                            : AppColors.gray300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Icon(
                      isArchived
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _statusConfig(String status) {
    switch (status.toUpperCase()) {
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
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
