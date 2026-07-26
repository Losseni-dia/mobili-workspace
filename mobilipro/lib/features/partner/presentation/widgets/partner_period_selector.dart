import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

enum PartnerPeriodMode { today, week, month, custom }

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
      return '${f.format(customFrom!)} → ${f.format(customTo!)}';
    }
    return switch (mode) {
      PartnerPeriodMode.today => "Aujourd'hui",
      PartnerPeriodMode.week => '7 jours',
      PartnerPeriodMode.month => '1 mois',
      PartnerPeriodMode.custom => 'Calendrier',
    };
  }

  DateTime get fromAsDate {
    if (isCustom && customFrom != null) return customFrom!;
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
  }

  DateTime get toAsDate {
    if (isCustom && customTo != null) return customTo!;
    return DateTime.now();
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
      firstDate: DateTime(now.year - 3),
      lastDate: now,
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
        onTap: () => _pickRange(context),
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
