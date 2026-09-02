import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../widgets/admin_period_selector.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════

class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.totalPartners,
    required this.totalTrips,
    required this.totalTripsThisYear,
    required this.tripsWithoutSalesThisYear,
    required this.activeBookings,
    required this.totalTickets,
    required this.totalRevenue,
    required this.revenueOnline,
    required this.revenueOffline,
  });
  final int totalUsers, totalPartners, totalTrips, activeBookings, totalTickets;
  /// Trajets dont le départ tombe dans l'année civile en cours, tout statut confondu —
  /// comparable à "Trajets avec ventes" de Stats métier (même filtre de date), affiché à côté de
  /// totalTrips (all-time, sans filtre) pour rendre lisible l'écart entre les deux (trajets sans
  /// aucune vente sur l'année).
  final int totalTripsThisYear;
  /// = totalTripsThisYear - trajets distincts avec ≥1 ticket vendu sur l'année.
  final int tripsWithoutSalesThisYear;
  final double totalRevenue;
  /// Répartition all-time du CA par canal (CONFIRMED = en ligne, OFFLINE_SALE = guichet) —
  /// voir AdminStatsResponse.revenueOnline/Offline (backend). totalRevenue = leur somme.
  final double revenueOnline, revenueOffline;
  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
    totalUsers: (j['totalUsers'] as num?)?.toInt() ?? 0,
    totalPartners: (j['totalPartners'] as num?)?.toInt() ?? 0,
    totalTrips: (j['totalTrips'] as num?)?.toInt() ?? 0,
    totalTripsThisYear: (j['totalTripsThisYear'] as num?)?.toInt() ?? 0,
    tripsWithoutSalesThisYear: (j['tripsWithoutSalesThisYear'] as num?)?.toInt() ?? 0,
    activeBookings: (j['activeBookings'] as num?)?.toInt() ?? 0,
    totalTickets: (j['totalTickets'] as num?)?.toInt() ?? 0,
    totalRevenue: (j['totalRevenue'] as num?)?.toDouble() ?? 0,
    revenueOnline: (j['revenueOnline'] as num?)?.toDouble() ?? 0,
    revenueOffline: (j['revenueOffline'] as num?)?.toDouble() ?? 0,
  );
}

class DailyLoginStats {
  const DailyLoginStats({
    required this.todayTotalLogins,
    required this.todayUniqueUsers,
    required this.history,
  });
  final int todayTotalLogins, todayUniqueUsers;
  final List<DayEntry> history;
  factory DailyLoginStats.fromJson(Map<String, dynamic> j) => DailyLoginStats(
    todayTotalLogins: (j['todayTotalLogins'] as num?)?.toInt() ?? 0,
    todayUniqueUsers: (j['todayUniqueUsers'] as num?)?.toInt() ?? 0,
    history: (j['history'] as List<dynamic>? ?? [])
        .map((e) => DayEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class DayEntry {
  const DayEntry({
    required this.date,
    required this.totalLogins,
    required this.uniqueUsers,
  });
  final String date;
  final int totalLogins, uniqueUsers;
  factory DayEntry.fromJson(Map<String, dynamic> j) => DayEntry(
    date: j['date'] as String? ?? '',
    totalLogins: (j['totalLogins'] as num?)?.toInt() ?? 0,
    uniqueUsers: (j['uniqueUsers'] as num?)?.toInt() ?? 0,
  );
}

/// Aligné sur AdminTripStatsResponse (backend) — ticketCount/totalTickets comptent des TICKETS
/// (unité = un siège vendu), jamais des réservations : une résa de 3 places = 1 booking mais
/// 3 tickets. Champs renommés le 2026-09-01 côté backend (totalBookings -> totalTickets,
/// bookingCount -> ticketCount, etc.) — ce modèle Dart consommait encore les anciens noms de
/// champs, silencieusement retombés à 0 après le déploiement (`?? 0`) : corrigé ici en même
/// temps que l'ajout des nouveaux champs (canal de vente, forfait/commission, deltas, courbe).
class TripStats {
  const TripStats({
    required this.totalTickets,
    required this.totalRevenueFcfa,
    required this.activeTripCount,
    required this.avgRevenuePerTicket,
    required this.revenueOnlineFcfa,
    required this.revenueOfflineFcfa,
    required this.totalServiceFeeFcfa,
    required this.totalCommissionFcfa,
    required this.netCompanyFcfa,
    required this.previousTotalTickets,
    required this.previousTotalRevenueFcfa,
    required this.ticketsDeltaPercent,
    required this.revenueDeltaPercent,
    required this.top10ByTickets,
    required this.top10ByRevenue,
    required this.timeline,
    required this.period,
  });
  final int totalTickets, activeTripCount;
  final double totalRevenueFcfa, avgRevenuePerTicket;
  final double revenueOnlineFcfa, revenueOfflineFcfa;
  final double totalServiceFeeFcfa, totalCommissionFcfa, netCompanyFcfa;
  final int? previousTotalTickets;
  final double? previousTotalRevenueFcfa;
  final double? ticketsDeltaPercent, revenueDeltaPercent;
  final List<TripStatEntry> top10ByTickets, top10ByRevenue;
  final List<TripStatsDayEntry> timeline;
  final String period;
  factory TripStats.fromJson(Map<String, dynamic> j, String period) =>
      TripStats(
        totalTickets: (j['totalTickets'] as num?)?.toInt() ?? 0,
        totalRevenueFcfa: (j['totalRevenueFcfa'] as num?)?.toDouble() ?? 0,
        activeTripCount: (j['activeTripCount'] as num?)?.toInt() ?? 0,
        avgRevenuePerTicket:
            (j['avgRevenuePerTicket'] as num?)?.toDouble() ?? 0,
        revenueOnlineFcfa: (j['revenueOnlineFcfa'] as num?)?.toDouble() ?? 0,
        revenueOfflineFcfa: (j['revenueOfflineFcfa'] as num?)?.toDouble() ?? 0,
        totalServiceFeeFcfa:
            (j['totalServiceFeeFcfa'] as num?)?.toDouble() ?? 0,
        totalCommissionFcfa:
            (j['totalCommissionFcfa'] as num?)?.toDouble() ?? 0,
        netCompanyFcfa: (j['netCompanyFcfa'] as num?)?.toDouble() ?? 0,
        previousTotalTickets: (j['previousTotalTickets'] as num?)?.toInt(),
        previousTotalRevenueFcfa: (j['previousTotalRevenueFcfa'] as num?)
            ?.toDouble(),
        ticketsDeltaPercent: (j['ticketsDeltaPercent'] as num?)?.toDouble(),
        revenueDeltaPercent: (j['revenueDeltaPercent'] as num?)?.toDouble(),
        top10ByTickets: (j['top10ByTickets'] as List<dynamic>? ?? [])
            .map((e) => TripStatEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        top10ByRevenue: (j['top10ByRevenue'] as List<dynamic>? ?? [])
            .map((e) => TripStatEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        timeline: (j['timeline'] as List<dynamic>? ?? [])
            .map((e) => TripStatsDayEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        period: period,
      );
}

class TripStatEntry {
  const TripStatEntry({
    required this.rank,
    required this.tripId,
    required this.route,
    required this.partnerName,
    required this.stationName,
    required this.ticketCount,
    required this.revenueFcfa,
  });
  final int rank, tripId, ticketCount;
  final String route, partnerName, stationName;
  final double revenueFcfa;
  factory TripStatEntry.fromJson(Map<String, dynamic> j) => TripStatEntry(
    rank: (j['rank'] as num?)?.toInt() ?? 0,
    tripId: (j['tripId'] as num?)?.toInt() ?? 0,
    route: j['route'] as String? ?? '',
    partnerName: j['partnerName'] as String? ?? '',
    stationName: j['stationName'] as String? ?? '—',
    ticketCount: (j['ticketCount'] as num?)?.toInt() ?? 0,
    revenueFcfa: (j['revenueFcfa'] as num?)?.toDouble() ?? 0,
  );
}

/// Un point de la courbe de croissance — un jour civil.
class TripStatsDayEntry {
  const TripStatsDayEntry({required this.date, required this.ticketCount, required this.revenueFcfa});
  final String date;
  final int ticketCount;
  final double revenueFcfa;
  factory TripStatsDayEntry.fromJson(Map<String, dynamic> j) =>
      TripStatsDayEntry(
        date: j['date'] as String? ?? '',
        ticketCount: (j['ticketCount'] as num?)?.toInt() ?? 0,
        revenueFcfa: (j['revenueFcfa'] as num?)?.toDouble() ?? 0,
      );
}

/// Option de filtre gare (Stats métier) — toutes compagnies confondues.
class AdminStationOption {
  const AdminStationOption({
    required this.id,
    required this.name,
    required this.partnerName,
  });
  final int id;
  final String name, partnerName;
  factory AdminStationOption.fromJson(Map<String, dynamic> j) =>
      AdminStationOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        partnerName: j['partnerName'] as String? ?? '',
      );
}

class RegistrationStats {
  const RegistrationStats({
    required this.todayRegistrations,
    required this.totalUsers,
    required this.history,
  });
  final int todayRegistrations, totalUsers;
  final List<RegistrationDayEntry> history;
  factory RegistrationStats.fromJson(Map<String, dynamic> j) =>
      RegistrationStats(
        todayRegistrations: (j['todayRegistrations'] as num?)?.toInt() ?? 0,
        totalUsers: (j['totalUsers'] as num?)?.toInt() ?? 0,
        history: (j['history'] as List<dynamic>? ?? [])
            .map(
              (e) => RegistrationDayEntry.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

class RegistrationDayEntry {
  const RegistrationDayEntry({required this.date, required this.count});
  final String date;
  final int count;
  factory RegistrationDayEntry.fromJson(Map<String, dynamic> j) =>
      RegistrationDayEntry(
        date: j['date'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class PartnerStats {
  const PartnerStats({
    required this.todayRegistrations,
    required this.totalPartners,
    required this.history,
  });
  final int todayRegistrations, totalPartners;
  final List<RegistrationDayEntry> history;
  factory PartnerStats.fromJson(Map<String, dynamic> j) => PartnerStats(
    todayRegistrations: (j['todayRegistrations'] as num?)?.toInt() ?? 0,
    totalPartners: (j['totalPartners'] as num?)?.toInt() ?? 0,
    history: (j['history'] as List<dynamic>? ?? [])
        .map((e) => RegistrationDayEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class TicketStats {
  const TicketStats({
    required this.todayTickets,
    required this.totalTickets,
    required this.history,
  });
  final int todayTickets, totalTickets;
  final List<RegistrationDayEntry> history;
  factory TicketStats.fromJson(Map<String, dynamic> j) => TicketStats(
    todayTickets: (j['todayTickets'] as num?)?.toInt() ?? 0,
    totalTickets: (j['totalTickets'] as num?)?.toInt() ?? 0,
    history: (j['history'] as List<dynamic>? ?? [])
        .map((e) => RegistrationDayEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class CovoiturageStats {
  const CovoiturageStats({
    required this.todayRegistrations,
    required this.totalDrivers,
    required this.history,
  });
  final int todayRegistrations, totalDrivers;
  final List<RegistrationDayEntry> history;
  factory CovoiturageStats.fromJson(Map<String, dynamic> j) => CovoiturageStats(
    todayRegistrations: (j['todayRegistrations'] as num?)?.toInt() ?? 0,
    totalDrivers: (j['totalDrivers'] as num?)?.toInt() ?? 0,
    history: (j['history'] as List<dynamic>? ?? [])
        .map((e) => RegistrationDayEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class AdminTicketListItem {
  const AdminTicketListItem({
    required this.id,
    required this.ticketNumber,
    required this.passengerName,
    required this.route,
    required this.partnerName,
    required this.stationName,
    required this.bookingDate,
    required this.departureDateTime,
    required this.amountPaid,
    required this.status,
    required this.seatNumber,
    required this.scanned,
    required this.bookingStatus,
  });
  final int id;
  final String ticketNumber,
      passengerName,
      route,
      partnerName,
      stationName,
      status,
      seatNumber;
  final DateTime bookingDate;
  /// Date de départ du voyage — distincte de bookingDate (date d'achat), voir
  /// GareTicketItem.departureDateTime (tickets_gare_page.dart).
  final DateTime? departureDateTime;
  final double amountPaid;
  final bool scanned;
  /// Statut de la réservation d'origine — distingue vente en ligne (CONFIRMED) / guichet
  /// (OFFLINE_SALE), distinct du statut du ticket lui-même.
  final String? bookingStatus;

  factory AdminTicketListItem.fromJson(Map<String, dynamic> j) =>
      AdminTicketListItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        ticketNumber: j['ticketNumber'] as String? ?? '',
        passengerName: j['passengerName'] as String? ?? '',
        route: j['route'] as String? ?? '',
        partnerName: j['partnerName'] as String? ?? '',
        stationName: j['stationName'] as String? ?? '—',
        bookingDate:
            DateTime.tryParse(j['bookingDate'] as String? ?? '') ??
            DateTime.now(),
        departureDateTime: DateTime.tryParse(
          j['departureDateTime'] as String? ?? '',
        ),
        amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
        seatNumber: j['seatNumber'] as String? ?? '',
        scanned: j['scanned'] as bool? ?? false,
        bookingStatus: j['bookingStatus'] as String?,
      );
}

class AdminBookingListItem {
  const AdminBookingListItem({
    required this.id,
    required this.reference,
    required this.customerName,
    required this.route,
    required this.partnerName,
    required this.stationName,
    required this.bookingDate,
    required this.departureDateTime,
    required this.numberOfSeats,
    required this.totalPrice,
    required this.status,
  });
  final int id, numberOfSeats;
  final String reference, customerName, route, partnerName, stationName, status;
  final DateTime bookingDate;
  /// Date de départ du voyage — distincte de bookingDate (date de réservation).
  final DateTime? departureDateTime;
  final double totalPrice;

  factory AdminBookingListItem.fromJson(Map<String, dynamic> j) =>
      AdminBookingListItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        reference: j['reference'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        route: j['route'] as String? ?? '',
        partnerName: j['partnerName'] as String? ?? '',
        stationName: j['stationName'] as String? ?? '—',
        bookingDate:
            DateTime.tryParse(j['bookingDate'] as String? ?? '') ??
            DateTime.now(),
        departureDateTime: DateTime.tryParse(
          j['departureDateTime'] as String? ?? '',
        ),
        numberOfSeats: (j['numberOfSeats'] as num?)?.toInt() ?? 0,
        totalPrice: (j['totalPrice'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
      );
}

/// Une ligne = une réservation payée — décompose ce qui a été encaissé entre frais Mobili
/// (forfait, jamais reversé), commission prélevée sur la compagnie, et net compagnie.
class AdminTransaction {
  const AdminTransaction({
    required this.bookingId,
    required this.reference,
    required this.date,
    required this.departureDateTime,
    required this.customerName,
    required this.route,
    required this.companyId,
    required this.companyName,
    required this.stationId,
    required this.stationName,
    required this.ticketsAmount,
    required this.serviceFee,
    required this.luggageFee,
    required this.commissionTotal,
    required this.companyNet,
    required this.totalPrice,
    required this.status,
  });

  final int bookingId, serviceFee, commissionTotal;
  final int? companyId, stationId;
  final String reference, customerName, route, companyName, stationName, status;
  final DateTime date;
  /// Date de départ du voyage — distincte de date (date de réservation).
  final DateTime? departureDateTime;
  final double ticketsAmount, luggageFee, companyNet, totalPrice;

  factory AdminTransaction.fromJson(Map<String, dynamic> j) => AdminTransaction(
        bookingId: (j['bookingId'] as num?)?.toInt() ?? 0,
        reference: j['reference'] as String? ?? '',
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        departureDateTime: DateTime.tryParse(
          j['departureDateTime'] as String? ?? '',
        ),
        customerName: j['customerName'] as String? ?? '',
        route: j['route'] as String? ?? '',
        companyId: (j['companyId'] as num?)?.toInt(),
        companyName: j['companyName'] as String? ?? '',
        stationId: (j['stationId'] as num?)?.toInt(),
        stationName: j['stationName'] as String? ?? '',
        ticketsAmount: (j['ticketsAmount'] as num?)?.toDouble() ?? 0,
        serviceFee: (j['serviceFee'] as num?)?.toInt() ?? 0,
        luggageFee: (j['luggageFee'] as num?)?.toDouble() ?? 0,
        commissionTotal: (j['commissionTotal'] as num?)?.toInt() ?? 0,
        companyNet: (j['companyNet'] as num?)?.toDouble() ?? 0,
        totalPrice: (j['totalPrice'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
      );
}

class AdminTripListItem {
  const AdminTripListItem({
    required this.id,
    required this.route,
    required this.partnerName,
    required this.stationName,
    required this.departureDateTime,
    required this.totalSeats,
    required this.availableSeats,
    required this.price,
    required this.status,
  });
  final int id, totalSeats, availableSeats;
  final String route, partnerName, stationName, status;
  final DateTime departureDateTime;
  final double price;

  factory AdminTripListItem.fromJson(Map<String, dynamic> j) =>
      AdminTripListItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        route: j['route'] as String? ?? '',
        partnerName: j['partnerName'] as String? ?? '',
        stationName: j['stationName'] as String? ?? '—',
        departureDateTime:
            DateTime.tryParse(j['departureDateTime'] as String? ?? '') ??
            DateTime.now(),
        totalSeats: (j['totalSeats'] as num?)?.toInt() ?? 0,
        availableSeats: (j['availableSeats'] as num?)?.toInt() ?? 0,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
    '/admin/stats',
  );
  return AdminStats.fromJson(res.data!);
});

final dailyLoginStatsProvider = FutureProvider.autoDispose
    .family<DailyLoginStats, AdminStatsPeriod>((ref, period) async {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/admin/stats/daily-logins',
        queryParameters: period.toQueryParams(),
      );
      return DailyLoginStats.fromJson(res.data!);
    });

/// Args de tripStatsProvider — station/compagnie optionnels (filtres Stats métier). Record :
/// égalité structurelle automatique, compatible avec .family (comme AdminStatsPeriod).
typedef TripStatsArgs = ({
  AdminStatsPeriod period,
  int? stationId,
  int? partnerId,
});

/// Toujours envoyé en period=CUSTOM avec fromAsDate/toAsDate (bornes calendaires : lundi→
/// dimanche pour "7 jours", 1er→dernier jour du mois pour "1 mois"...), jamais period=WEEK/MONTH
/// laissé au backend — celui-ci calcule alors une fenêtre GLISSANTE plafonnée à maintenant,
/// aveugle à toute vente déjà faite pour une date future dans la période (même bug que corrigé
/// côté web le 2026-09-01, voir admin-business.ts). fromAsDate/toAsDate est déjà la convention
/// de toutes les autres pages admin/partenaire/gare (trips_list_page, partner_trips_list_page,
/// bookings_gare_page...) — seule cette page ne l'utilisait pas encore.
final tripStatsProvider = FutureProvider.autoDispose
    .family<TripStats, TripStatsArgs>((ref, args) async {
      final f = DateFormat('yyyy-MM-dd');
      final qp = <String, dynamic>{
        'period': 'CUSTOM',
        'fromDate': f.format(args.period.fromAsDate),
        'toDate': f.format(args.period.toAsDate),
        if (args.stationId != null) 'stationId': args.stationId,
        if (args.partnerId != null) 'partnerId': args.partnerId,
      };
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/admin/stats/trip-analytics',
        queryParameters: qp,
      );
      return TripStats.fromJson(res.data!, 'CUSTOM');
    });

final adminStationOptionsProvider =
    FutureProvider.autoDispose<List<AdminStationOption>>((ref) async {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin/stats/stations',
      );
      return (res.data ?? [])
          .map((e) => AdminStationOption.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final registrationStatsProvider = FutureProvider.autoDispose
    .family<RegistrationStats, AdminStatsPeriod>((ref, period) async {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/admin/stats/registrations',
        queryParameters: period.toQueryParams(),
      );
      return RegistrationStats.fromJson(res.data!);
    });

final partnerStatsProvider = FutureProvider.autoDispose
    .family<PartnerStats, AdminStatsPeriod>((ref, period) async {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/admin/stats/partners',
        queryParameters: period.toQueryParams(),
      );
      return PartnerStats.fromJson(res.data!);
    });

final ticketStatsProvider = FutureProvider.autoDispose
    .family<TicketStats, AdminStatsPeriod>((ref, period) async {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/admin/stats/tickets',
        queryParameters: period.toQueryParams(),
      );
      return TicketStats.fromJson(res.data!);
    });

final covoiturageStatsProvider = FutureProvider.autoDispose
    .family<CovoiturageStats, AdminStatsPeriod>((ref, period) async {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/admin/stats/covoiturage',
        queryParameters: period.toQueryParams(),
      );
      return CovoiturageStats.fromJson(res.data!);
    });

final ticketListProvider = FutureProvider.autoDispose
    .family<
      List<AdminTicketListItem>,
      ({AdminStatsPeriod period, String search})
    >((ref, args) async {
      final f = DateFormat('yyyy-MM-dd');
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin/stats/tickets/list',
        queryParameters: {
          'fromDate': f.format(args.period.fromAsDate),
          'toDate': f.format(args.period.toAsDate),
          if (args.search.isNotEmpty) 'search': args.search,
        },
      );
      return (res.data ?? [])
          .map((e) => AdminTicketListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final bookingListProvider = FutureProvider.autoDispose
    .family<
      List<AdminBookingListItem>,
      ({AdminStatsPeriod period, String search})
    >((ref, args) async {
      final f = DateFormat('yyyy-MM-dd');
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin/stats/bookings/list',
        queryParameters: {
          'fromDate': f.format(args.period.fromAsDate),
          'toDate': f.format(args.period.toAsDate),
          if (args.search.isNotEmpty) 'search': args.search,
        },
      );
      return (res.data ?? [])
          .map((e) => AdminBookingListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final transactionListProvider = FutureProvider.autoDispose
    .family<
      List<AdminTransaction>,
      ({AdminStatsPeriod period, String search})
    >((ref, args) async {
      final f = DateFormat('yyyy-MM-dd');
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin/stats/transactions/list',
        queryParameters: {
          'fromDate': f.format(args.period.fromAsDate),
          'toDate': f.format(args.period.toAsDate),
          if (args.search.isNotEmpty) 'search': args.search,
        },
      );
      return (res.data ?? [])
          .map((e) => AdminTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final tripListProvider = FutureProvider.autoDispose
    .family<
      List<AdminTripListItem>,
      ({AdminStatsPeriod period, String search})
    >((ref, args) async {
      final f = DateFormat('yyyy-MM-dd');
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin/stats/trips/list',
        queryParameters: {
          'fromDate': f.format(args.period.fromAsDate),
          'toDate': f.format(args.period.toAsDate),
          if (args.search.isNotEmpty) 'search': args.search,
        },
      );
      return (res.data ?? [])
          .map((e) => AdminTripListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

