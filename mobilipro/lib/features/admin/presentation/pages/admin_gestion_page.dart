import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobilipro/core/services/analytics_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/theme/app_colors.dart';
import 'admin_gestion_page_v2.dart' show AdminPartner;

// ═══════════════════════════════════════════════════════════════════════════
// EXPORT CSV — utilisé par PartnerStatsDetailPage (partner_stats_page.dart),
// la page "Partenaires" réellement routée dans l'app. Le reste de ce fichier
// (page "Gestion" à onglets Partenaires/Utilisateurs/Covoiturage) a été
// retiré : il n'était câblé dans aucune route ni aucun Navigator.push,
// donc jamais atteignable — voir l'audit du bug "Approuver ne fonctionnait
// pas" (les vraies pages équivalentes sont partner_stats_page.dart,
// registration_stats_page.dart et covoiturage_stats_page.dart).
// ═══════════════════════════════════════════════════════════════════════════

Future<void> exportPartnersCsv(
  List<AdminPartner> partners,
  BuildContext context,
) async {
  final rows = [
    [
      'ID',
      'Nom',
      'Propriétaire',
      'Email',
      'Téléphone',
      'N° entreprise',
      'Statut',
      'Approbation',
    ],
    ...partners.map(
      (p) => [
        p.id,
        p.name,
        p.ownerName ?? '',
        p.email ?? '',
        p.phone ?? '',
        p.businessNumber ?? '',
        p.enabled ? 'Actif' : 'Inactif',
        p.approvalStatus,
      ],
    ),
  ];
  await _shareCsv(rows, 'partenaires', context);
  AnalyticsService.logExportCsv(type: 'partenaires');
}

Future<void> _shareCsv(
  List<List<dynamic>> rows,
  String name,
  BuildContext context,
) async {
  try {
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final filename =
        '${name}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Export Mobili — $name');
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

Future<void> exportPartnersPdf(
  List<AdminPartner> partners,
  BuildContext context,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(
          'Partenaires',
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
            'Nom',
            'Propriétaire',
            'Email',
            'Téléphone',
            'Statut',
            'Approbation',
          ],
          data: partners
              .map(
                (p) => [
                  p.name,
                  p.ownerName ?? '—',
                  p.email ?? '—',
                  p.phone ?? '—',
                  p.enabled ? 'Actif' : 'Inactif',
                  p.approvalStatus,
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
    '${dir.path}/partenaires_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  await Share.shareXFiles([
    XFile(file.path),
  ], subject: 'Export Mobili — Partenaires');
  AnalyticsService.logExportCsv(type: 'partenaires_pdf');
}
