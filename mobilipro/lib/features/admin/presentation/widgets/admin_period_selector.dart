import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

/// Paramètre de période transmis aux providers de stats admin.
/// Type record : égalité structurelle automatique (compatible Riverpod family).
typedef AdminStatsPeriod = ({int days, DateTime? fromDate, DateTime? toDate});

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

enum _CalendarChoice { range, single }

/// Bornes du calendrier volontairement très larges — dans le passé pour
/// retrouver n'importe quelle donnée historique, dans le futur pour filtrer
/// sur des trajets/réservations pas encore arrivés. Tous les mois de toutes
/// les années dans cette plage restent sélectionnables.
final DateTime _kCalendarFirstDate = DateTime(1990);
DateTime _kCalendarLastDate(DateTime now) => DateTime(now.year + 50);

const AdminStatsPeriod kPeriodToday = (days: 1, fromDate: null, toDate: null);
const AdminStatsPeriod kPeriodWeek = (days: 7, fromDate: null, toDate: null);
const AdminStatsPeriod kPeriodMonth = (days: 30, fromDate: null, toDate: null);

extension AdminStatsPeriodX on AdminStatsPeriod {
  bool get isCustom => fromDate != null && toDate != null;

  Map<String, dynamic> toQueryParams() {
    if (isCustom) {
      final f = DateFormat('yyyy-MM-dd');
      return {'fromDate': f.format(fromDate!), 'toDate': f.format(toDate!)};
    }
    return {'days': days};
  }

  String label() {
    if (isCustom) {
      final f = DateFormat('dd/MM/yy');
      if (_isSameDay(fromDate!, toDate!)) return f.format(fromDate!);
      return '${f.format(fromDate!)} → ${f.format(toDate!)}';
    }
    return switch (days) {
      1 => "Aujourd'hui",
      7 => '7 jours',
      30 => '1 mois',
      _ => '$days jours',
    };
  }
}

/// Sélecteur 4 modes : Aujourd'hui / Semaine / Mois / Intervalle personnalisé
/// (calendrier). Réutilisable sur toutes les pages détail admin.
class AdminPeriodSelector extends StatelessWidget {
  const AdminPeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final AdminStatsPeriod selected;
  final ValueChanged<AdminStatsPeriod> onChanged;

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: _kCalendarFirstDate,
      lastDate: _kCalendarLastDate(now),
      locale: const Locale('fr', 'FR'),
      initialDateRange: selected.isCustom
          ? DateTimeRange(start: selected.fromDate!, end: selected.toDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 29)),
              end: now,
            ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: AppColors.mobiliBlue),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      onChanged((days: 0, fromDate: range.start, toDate: range.end));
    }
  }

  Future<void> _pickSingleDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: _kCalendarFirstDate,
      lastDate: _kCalendarLastDate(now),
      locale: const Locale('fr', 'FR'),
      initialDate: selected.isCustom ? selected.fromDate! : now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: AppColors.mobiliBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onChanged((days: 0, fromDate: picked, toDate: picked));
    }
  }

  Future<void> _pickCalendar(BuildContext context) async {
    final choice = await showModalBottomSheet<_CalendarChoice>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.date_range_rounded,
                color: AppColors.mobiliBlue,
              ),
              title: const Text('Intervalle de dates'),
              onTap: () => Navigator.pop(ctx, _CalendarChoice.range),
            ),
            ListTile(
              leading: const Icon(
                Icons.today_rounded,
                color: AppColors.mobiliBlue,
              ),
              title: const Text('Une date précise'),
              onTap: () => Navigator.pop(ctx, _CalendarChoice.single),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == _CalendarChoice.range) {
      await _pickRange(context);
    } else {
      await _pickSingleDate(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _Chip(
        label: "Aujourd'hui",
        selected: !selected.isCustom && selected.days == 1,
        onTap: () => onChanged(kPeriodToday),
      ),
      _Chip(
        label: '7 jours',
        selected: !selected.isCustom && selected.days == 7,
        onTap: () => onChanged(kPeriodWeek),
      ),
      _Chip(
        label: '1 mois',
        selected: !selected.isCustom && selected.days == 30,
        onTap: () => onChanged(kPeriodMonth),
      ),
      _Chip(
        label: selected.isCustom ? selected.label() : 'Calendrier',
        selected: selected.isCustom,
        icon: Icons.calendar_month_rounded,
        onTap: () => _pickCalendar(context),
      ),
    ];
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map(
                (c) =>
                    Padding(padding: const EdgeInsets.only(right: 8), child: c),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.mobiliBlue : AppColors.gray100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.white : AppColors.gray600,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.white : AppColors.gray600,
            ),
          ),
        ],
      ),
    ),
  );
}


extension AdminStatsPeriodDates on AdminStatsPeriod {
  DateTime get fromAsDate {
    if (isCustom) return fromDate!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: days - 1));
  }

  DateTime get toAsDate {
    if (isCustom) return toDate!;
    return DateTime.now();
  }
}
