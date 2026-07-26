import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';
import '../pages/admin_gestion_page_v2.dart'
    show CovoiturageSoloDriver, AdminUser;

Future<void> shareExportFile(
  File file,
  String subject,
  BuildContext context,
) async {
  try {
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur export : $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> exportTicketsCsv(
  List<AdminTicketListItem> tickets,
  BuildContext context,
) async {
  final rows = [
    [
      'N° Ticket',
      'Passager',
      'Trajet',
      'Compagnie',
      'Date',
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
        t.partnerName,
        DateFormat('dd/MM/yyyy HH:mm').format(t.bookingDate),
        t.amountPaid.toStringAsFixed(0),
        t.status,
        t.seatNumber,
        t.scanned ? 'Oui' : 'Non',
      ],
    ),
  ];
  final csv = const ListToCsvConverter().convert(rows);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/tickets_${DateTime.now().millisecondsSinceEpoch}.csv',
  );
  await file.writeAsString(csv);
  await shareExportFile(file, 'Export Mobili — Tickets', context);
}

Future<void> exportTicketsPdf(
  List<AdminTicketListItem> tickets,
  BuildContext context,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          'Tickets vendus',
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
            'Compagnie',
            'Date',
            'Montant',
            'Statut',
          ],
          data: tickets
              .map(
                (t) => [
                  t.ticketNumber,
                  t.passengerName,
                  t.route,
                  t.partnerName,
                  DateFormat('dd/MM/yy HH:mm').format(t.bookingDate),
                  '${t.amountPaid.toStringAsFixed(0)} F',
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
    '${dir.path}/tickets_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  await shareExportFile(file, 'Export Mobili — Tickets', context);
}

Future<void> exportBookingsCsv(
  List<AdminBookingListItem> bookings,
  BuildContext context,
) async {
  final rows = [
    [
      'Référence',
      'Client',
      'Trajet',
      'Compagnie',
      'Date',
      'Places',
      'Montant FCFA',
      'Statut',
    ],
    ...bookings.map(
      (b) => [
        b.reference,
        b.customerName,
        b.route,
        b.partnerName,
        DateFormat('dd/MM/yyyy HH:mm').format(b.bookingDate),
        '${b.numberOfSeats}',
        b.totalPrice.toStringAsFixed(0),
        b.status,
      ],
    ),
  ];
  final csv = const ListToCsvConverter().convert(rows);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/reservations_${DateTime.now().millisecondsSinceEpoch}.csv',
  );
  await file.writeAsString(csv);
  await shareExportFile(file, 'Export Mobili — Réservations', context);
}

Future<void> exportBookingsPdf(
  List<AdminBookingListItem> bookings,
  BuildContext context,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          'Réservations',
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
            'Référence',
            'Client',
            'Trajet',
            'Compagnie',
            'Date',
            'Places',
            'Montant',
            'Statut',
          ],
          data: bookings
              .map(
                (b) => [
                  b.reference,
                  b.customerName,
                  b.route,
                  b.partnerName,
                  DateFormat('dd/MM/yy HH:mm').format(b.bookingDate),
                  '${b.numberOfSeats}',
                  '${b.totalPrice.toStringAsFixed(0)} F',
                  b.status,
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
    '${dir.path}/reservations_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  await shareExportFile(file, 'Export Mobili — Réservations', context);
}

Future<void> exportTripsCsv(
  List<AdminTripListItem> trips,
  BuildContext context,
) async {
  final rows = [
    [
      'Trajet',
      'Compagnie',
      'Départ',
      'Places totales',
      'Places restantes',
      'Prix FCFA',
      'Statut',
    ],
    ...trips.map(
      (t) => [
        t.route,
        t.partnerName,
        DateFormat('dd/MM/yyyy HH:mm').format(t.departureDateTime),
        '${t.totalSeats}',
        '${t.availableSeats}',
        t.price.toStringAsFixed(0),
        t.status,
      ],
    ),
  ];
  final csv = const ListToCsvConverter().convert(rows);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/trajets_${DateTime.now().millisecondsSinceEpoch}.csv',
  );
  await file.writeAsString(csv);
  await shareExportFile(file, 'Export Mobili — Trajets', context);
}

Future<void> exportTripsPdf(
  List<AdminTripListItem> trips,
  BuildContext context,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          'Trajets',
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
            'Trajet',
            'Compagnie',
            'Départ',
            'Places',
            'Prix',
            'Statut',
          ],
          data: trips
              .map(
                (t) => [
                  t.route,
                  t.partnerName,
                  DateFormat('dd/MM/yy HH:mm').format(t.departureDateTime),
                  '${t.availableSeats}/${t.totalSeats}',
                  '${t.price.toStringAsFixed(0)} F',
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
    '${dir.path}/trajets_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  await shareExportFile(file, 'Export Mobili — Trajets', context);
}

Future<void> exportUsersCsv(List<AdminUser> users, BuildContext context) async {
  final rows = [
    ['ID', 'Prénom', 'Nom', 'Email', 'Rôles', 'Statut', 'Compagnie'],
    ...users.map(
      (u) => [
        u.id,
        u.firstname,
        u.lastname,
        u.email ?? '',
        u.roles.join(' | '),
        u.enabled ? 'Actif' : 'Inactif',
        u.linkedCompanyName ?? '',
      ],
    ),
  ];
  final csv = const ListToCsvConverter().convert(rows);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/utilisateurs_${DateTime.now().millisecondsSinceEpoch}.csv',
  );
  await file.writeAsString(csv);
  await shareExportFile(file, 'Export Mobili — Utilisateurs', context);
}

Future<void> exportUsersPdf(List<AdminUser> users, BuildContext context) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          'Utilisateurs',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Nom', 'Email', 'Rôles', 'Statut', 'Compagnie'],
          data: users
              .map(
                (u) => [
                  u.fullName,
                  u.email ?? '—',
                  u.roles.join(', '),
                  u.enabled ? 'Actif' : 'Inactif',
                  u.linkedCompanyName ?? '—',
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
    '${dir.path}/utilisateurs_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  await shareExportFile(file, 'Export Mobili — Utilisateurs', context);
}

Future<void> exportCovoiturageCsv(
  List<CovoiturageSoloDriver> drivers,
  BuildContext context,
) async {
  final rows = [
    ['ID', 'Prénom', 'Nom', 'Email', 'Statut KYC', 'Compte'],
    ...drivers.map(
      (d) => [
        d.id,
        d.firstname,
        d.lastname,
        d.email ?? '',
        d.kycStatus ?? '',
        d.enabled ? 'Actif' : 'Inactif',
      ],
    ),
  ];
  final csv = const ListToCsvConverter().convert(rows);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/covoiturage_${DateTime.now().millisecondsSinceEpoch}.csv',
  );
  await file.writeAsString(csv);
  await shareExportFile(file, 'Export Mobili — Covoiturage', context);
}

Future<void> exportCovoituragePdf(
  List<CovoiturageSoloDriver> drivers,
  BuildContext context,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          'Chauffeurs covoiturage',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Prénom', 'Nom', 'Email', 'Statut KYC', 'Compte'],
          data: drivers
              .map(
                (d) => [
                  d.firstname,
                  d.lastname,
                  d.email ?? '—',
                  d.kycStatus ?? '—',
                  d.enabled ? 'Actif' : 'Inactif',
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
    '${dir.path}/covoiturage_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  await shareExportFile(file, 'Export Mobili — Covoiturage', context);
}
