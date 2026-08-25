import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

enum PartnerPeriodMode { today, week, month, custom }

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

enum _CalendarChoice { range, single }

/// Bornes du calendrier volontairement très larges — dans le passé pour
/// retrouver n'importe quelle donnée historique, dans le futur pour filtrer
/// sur des trajets/réservations pas encore arrivés. Tous les mois de toutes
/// les années dans cette plage restent sélectionnables.
final DateTime _kCalendarFirstDate = DateTime(1990);
DateTime _kCalendarLastDate(DateTime now) => DateTime(now.year + 50);

class PartnerPeriod {
  const PartnerPeriod({required this.mode, this.customFrom, this.customTo});

  final PartnerPeriodMode mode;
  final DateTime? customFrom;
  final DateTime? customTo;

  static const today = PartnerPeriod(mode: PartnerPeriodMode.today);
  static const week = PartnerPeriod(mode: PartnerPeriodMode.week);
  static const month = PartnerPeriod(mode: PartnerPeriodMode.month);

  bool get isCustom => mode == PartnerPeriodMode.custom;

  int get days => switch (mode) {
    PartnerPeriodMode.today => 1,
    PartnerPeriodMode.week => 7,
    PartnerPeriodMode.month => 30,
    PartnerPeriodMode.custom => 0,
  };

  String label() {
    if (isCustom && customFrom != null && customTo != null) {
      final f = DateFormat('dd/MM/yy');
      if (_isSameDay(customFrom!, customTo!)) return f.format(customFrom!);
      return '${f.format(customFrom!)} → ${f.format(customTo!)}';
    }
    return switch (mode) {
      PartnerPeriodMode.today => "Aujourd'hui",
      PartnerPeriodMode.week => '7 jours',
      PartnerPeriodMode.month => '1 mois',
      PartnerPeriodMode.custom => 'Calendrier',
    };
  }

  /// Bornes calées sur le calendrier (aligné sur computePeriodRange côté web) — jamais une
  /// fenêtre glissante : "1 mois" est le 1er au dernier jour du mois EN COURS (28/29/30/31
  /// selon le mois), pas "les 30 derniers jours", qui faussait les sommes affichées par
  /// rapport à un vrai mois calendaire.
  DateTime get fromAsDate {
    if (isCustom && customFrom != null) return customFrom!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (mode) {
      case PartnerPeriodMode.week:
        return today.subtract(Duration(days: today.weekday - 1)); // lundi
      case PartnerPeriodMode.month:
        return DateTime(today.year, today.month, 1); // 1er du mois
      case PartnerPeriodMode.today:
      case PartnerPeriodMode.custom:
        return today;
    }
  }

  DateTime get toAsDate {
    if (isCustom && customTo != null) return customTo!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (mode) {
      case PartnerPeriodMode.week:
        return today.add(Duration(days: 7 - today.weekday)); // dimanche
      case PartnerPeriodMode.month:
        return DateTime(today.year, today.month + 1, 0); // dernier jour du mois
      case PartnerPeriodMode.today:
      case PartnerPeriodMode.custom:
        return now; // jusqu'à l'instant présent
    }
  }
}

class PartnerPeriodSelector extends StatelessWidget {
  const PartnerPeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final PartnerPeriod selected;
  final ValueChanged<PartnerPeriod> onChanged;

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: _kCalendarFirstDate,
      lastDate: _kCalendarLastDate(now),
      locale: const Locale('fr', 'FR'),
      initialDateRange: selected.isCustom && selected.customFrom != null
          ? DateTimeRange(start: selected.customFrom!, end: selected.customTo!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 6)),
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
      onChanged(
        PartnerPeriod(
          mode: PartnerPeriodMode.custom,
          customFrom: range.start,
          customTo: range.end,
        ),
      );
    }
  }

  Future<void> _pickSingleDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: _kCalendarFirstDate,
      lastDate: _kCalendarLastDate(now),
      locale: const Locale('fr', 'FR'),
      initialDate: selected.isCustom && selected.customFrom != null
          ? selected.customFrom!
          : now,
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
      onChanged(
        PartnerPeriod(
          mode: PartnerPeriodMode.custom,
          customFrom: picked,
          customTo: picked,
        ),
      );
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
        selected: selected.mode == PartnerPeriodMode.today,
        onTap: () => onChanged(PartnerPeriod.today),
      ),
      _Chip(
        label: '7 jours',
        selected: selected.mode == PartnerPeriodMode.week,
        onTap: () => onChanged(PartnerPeriod.week),
      ),
      _Chip(
        label: '1 mois',
        selected: selected.mode == PartnerPeriodMode.month,
        onTap: () => onChanged(PartnerPeriod.month),
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
