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
    required this.activeBookings,
    required this.totalTickets,
    required this.totalRevenue,
  });
  final int totalUsers, totalPartners, totalTrips, activeBookings, totalTickets;
  final double totalRevenue;
  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
    totalUsers: (j['totalUsers'] as num?)?.toInt() ?? 0,
    totalPartners: (j['totalPartners'] as num?)?.toInt() ?? 0,
    totalTrips: (j['totalTrips'] as num?)?.toInt() ?? 0,
    activeBookings: (j['activeBookings'] as num?)?.toInt() ?? 0,
    totalTickets: (j['totalTickets'] as num?)?.toInt() ?? 0,
    totalRevenue: (j['totalRevenue'] as num?)?.toDouble() ?? 0,
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

class TripStats {
  const TripStats({
    required this.totalBookings,
    required this.totalRevenueFcfa,
    required this.activeTripCount,
    required this.avgRevenuePerBooking,
    required this.top10ByBookings,
    required this.top10ByRevenue,
    required this.period,
  });
  final int totalBookings, activeTripCount;
  final double totalRevenueFcfa, avgRevenuePerBooking;
  final List<TripStatEntry> top10ByBookings, top10ByRevenue;
  final String period;
  factory TripStats.fromJson(Map<String, dynamic> j, String period) =>
      TripStats(
        totalBookings: (j['totalBookings'] as num?)?.toInt() ?? 0,
        totalRevenueFcfa: (j['totalRevenueFcfa'] as num?)?.toDouble() ?? 0,
        activeTripCount: (j['activeTripCount'] as num?)?.toInt() ?? 0,
        avgRevenuePerBooking:
            (j['avgRevenuePerBooking'] as num?)?.toDouble() ?? 0,
        top10ByBookings: (j['top10ByBookings'] as List<dynamic>? ?? [])
            .map((e) => TripStatEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        top10ByRevenue: (j['top10ByRevenue'] as List<dynamic>? ?? [])
            .map((e) => TripStatEntry.fromJson(e as Map<String, dynamic>))
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
    required this.bookingCount,
    required this.revenueFcfa,
  });
  final int rank, tripId, bookingCount;
  final String route, partnerName;
  final double revenueFcfa;
  factory TripStatEntry.fromJson(Map<String, dynamic> j) => TripStatEntry(
    rank: (j['rank'] as num?)?.toInt() ?? 0,
    tripId: (j['tripId'] as num?)?.toInt() ?? 0,
    route: j['route'] as String? ?? '',
    partnerName: j['partnerName'] as String? ?? '',
    bookingCount: (j['bookingCount'] as num?)?.toInt() ?? 0,
    revenueFcfa: (j['revenueFcfa'] as num?)?.toDouble() ?? 0,
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
    required this.bookingDate,
    required this.amountPaid,
    required this.status,
    required this.seatNumber,
    required this.scanned,
  });
  final int id;
  final String ticketNumber,
      passengerName,
      route,
      partnerName,
      status,
      seatNumber;
  final DateTime bookingDate;
  final double amountPaid;
  final bool scanned;

  factory AdminTicketListItem.fromJson(Map<String, dynamic> j) =>
      AdminTicketListItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        ticketNumber: j['ticketNumber'] as String? ?? '',
        passengerName: j['passengerName'] as String? ?? '',
        route: j['route'] as String? ?? '',
        partnerName: j['partnerName'] as String? ?? '',
        bookingDate:
            DateTime.tryParse(j['bookingDate'] as String? ?? '') ??
            DateTime.now(),
        amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
        seatNumber: j['seatNumber'] as String? ?? '',
        scanned: j['scanned'] as bool? ?? false,
      );
}

class AdminBookingListItem {
  const AdminBookingListItem({
    required this.id,
    required this.reference,
    required this.customerName,
    required this.route,
    required this.partnerName,
    required this.bookingDate,
    required this.numberOfSeats,
    required this.totalPrice,
    required this.status,
  });
  final int id, numberOfSeats;
  final String reference, customerName, route, partnerName, status;
  final DateTime bookingDate;
  final double totalPrice;

  factory AdminBookingListItem.fromJson(Map<String, dynamic> j) =>
      AdminBookingListItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        reference: j['reference'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        route: j['route'] as String? ?? '',
        partnerName: j['partnerName'] as String? ?? '',
        bookingDate:
            DateTime.tryParse(j['bookingDate'] as String? ?? '') ??
            DateTime.now(),
        numberOfSeats: (j['numberOfSeats'] as num?)?.toInt() ?? 0,
        totalPrice: (j['totalPrice'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
      );
}

class AdminTripListItem {
  const AdminTripListItem({
    required this.id,
    required this.route,
    required this.partnerName,
    required this.departureDateTime,
    required this.totalSeats,
    required this.availableSeats,
    required this.price,
    required this.status,
  });
  final int id, totalSeats, availableSeats;
  final String route, partnerName, status;
  final DateTime departureDateTime;
  final double price;

  factory AdminTripListItem.fromJson(Map<String, dynamic> j) =>
      AdminTripListItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        route: j['route'] as String? ?? '',
        partnerName: j['partnerName'] as String? ?? '',
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

final tripStatsProvider = FutureProvider.autoDispose
    .family<TripStats, AdminStatsPeriod>((ref, period) async {
      final qp = <String, dynamic>{};
      String periodLabel;
      if (period.isCustom) {
        periodLabel = 'CUSTOM';
        qp['period'] = 'CUSTOM';
        qp.addAll(period.toQueryParams());
      } else {
        periodLabel = switch (period.days) {
          1 => 'DAY',
          7 => 'WEEK',
          _ => 'MONTH',
        };
        qp['period'] = periodLabel;
      }
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/admin/stats/trip-analytics',
        queryParameters: qp,
      );
      return TripStats.fromJson(res.data!, periodLabel);
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

