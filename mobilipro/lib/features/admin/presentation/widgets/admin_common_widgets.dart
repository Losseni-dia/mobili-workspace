import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_stats_models.dart';

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.mobiliBlueDeep,
    ),
  );
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });
  final IconData icon;
  final String label, value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: color,
                ),
              ),
            Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.gray500),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gray200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.mobiliBlueDeep,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class AdminTableCard extends StatelessWidget {
  const AdminTableCard({
    super.key,
    required this.headers,
    required this.rows,
    required this.colors,
  });
  final List<String> headers;
  final List<List<String>> rows;
  final List<Color?> colors;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gray200),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: headers
                .asMap()
                .entries
                .map(
                  (e) => e.key == 0
                      ? Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gray500,
                            ),
                          ),
                        )
                      : SizedBox(
                          width: 70,
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gray500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                )
                .toList(),
          ),
        ),
        const Divider(height: 1, color: AppColors.gray100),
        ...rows.map(
          (row) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                child: Row(
                  children: row
                      .asMap()
                      .entries
                      .map(
                        (e) => e.key == 0
                            ? Expanded(
                                child: Text(
                                  e.value,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mobiliBlueDeep,
                                  ),
                                ),
                              )
                            : SizedBox(
                                width: 70,
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        colors[e.key] ??
                                        AppColors.mobiliBlueDeep,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                      )
                      .toList(),
                ),
              ),
              const Divider(height: 1, color: AppColors.gray100),
            ],
          ),
        ),
      ],
    ),
  );
}

class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({
    super.key,
    required this.remaining,
    required this.onTap,
  });
  final int remaining;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.expand_more_rounded, size: 18),
      label: Text('Charger 20 de plus ($remaining restants)'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mobiliBlue,
        side: const BorderSide(color: AppColors.mobiliBlue),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

class RevenueCard extends StatelessWidget {
  const RevenueCard({super.key, required this.revenue, this.subtitle});
  final double revenue;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             Text(
                subtitle != null ? 'Revenus plateforme — $subtitle' : 'Revenus totaux',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${NumberFormat('#,###').format(revenue)} FCFA',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AdminLoadingCard extends StatelessWidget {
  const AdminLoadingCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Center(
      child: CircularProgressIndicator(color: AppColors.mobiliBlue),
    ),
  );
}

class AdminErrorCard extends StatelessWidget {
  const AdminErrorCard({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.dangerSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.danger,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class AdminLineChartWidget extends StatefulWidget {
  const AdminLineChartWidget({
    super.key,
    required this.entries,
    required this.getValue,
    required this.getDate,
    required this.color,
    this.showTooltip = false,
  });
  final List<dynamic> entries;
  final double Function(dynamic) getValue;
  final String Function(dynamic) getDate;
  final Color color;
  final bool showTooltip;
  @override
  State<AdminLineChartWidget> createState() => _AdminLineChartWidgetState();
}

class _AdminLineChartWidgetState extends State<AdminLineChartWidget> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    final spots = widget.entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), widget.getValue(e.value)))
        .toList();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        minY: (minY - (maxY - minY) * 0.1).clamp(0, double.infinity),
        maxY: maxY + (maxY - minY) * 0.1 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.gray100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: widget.entries.length > 14
                  ? (widget.entries.length / 5).roundToDouble()
                  : 1,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= widget.entries.length)
                  return const SizedBox.shrink();
                final date = widget.getDate(widget.entries[i]);
                final short = date.length >= 5 ? date.substring(5) : date;
                return Text(
                  short,
                  style: const TextStyle(fontSize: 8, color: AppColors.gray400),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: widget.showTooltip,
          touchCallback: (event, response) {
            if (response?.lineBarSpots != null && event is FlTapUpEvent) {
              setState(
                () => _touchedIndex = response!.lineBarSpots!.first.spotIndex,
              );
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.mobiliBlueDeep,
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${s.y.toInt()}\n${widget.getDate(widget.entries[s.spotIndex])}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: widget.color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: widget.entries.length <= 14,
              getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
                radius: _touchedIndex == i ? 5 : 3,
                color: widget.color,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  widget.color.withValues(alpha: 0.25),
                  widget.color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class KpiCardWithBadge extends StatelessWidget {
  const KpiCardWithBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.badgeCount,
    this.subtitle,
  });
  final IconData icon;
  final String label, value;
  final Color color;
  final int badgeCount;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      KpiCard(
        icon: icon,
        label: label,
        value: value,
        color: color,
        subtitle: subtitle,
      ),
      if (badgeCount > 0)
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );
}

class AdminHorizontalBarChart extends StatefulWidget {
  const AdminHorizontalBarChart({
    super.key,
    required this.entries,
    required this.showRevenue,
  });
  final List<TripStatEntry> entries;
  final bool showRevenue;
  @override
  State<AdminHorizontalBarChart> createState() =>
      _AdminHorizontalBarChartState();
}

class _AdminHorizontalBarChartState extends State<AdminHorizontalBarChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final color = widget.showRevenue ? AppColors.proGold : AppColors.mobiliBlue;
    final maxVal = widget.entries.fold<double>(
      1,
      (m, e) => widget.showRevenue
          ? (e.revenueFcfa > m ? e.revenueFcfa : m)
          : (e.bookingCount > m ? e.bookingCount.toDouble() : m),
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent)
              setState(
                () => _touchedIndex = response?.spot?.touchedBarGroupIndex,
              );
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.mobiliBlueDeep,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final e = widget.entries[groupIndex];
              final val = widget.showRevenue
                  ? '${NumberFormat('#,###').format(e.revenueFcfa)} F'
                  : '${e.bookingCount} rés.';
              return BarTooltipItem(
                '${e.route}\n$val',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= widget.entries.length)
                  return const SizedBox.shrink();
                final route = widget.entries[i].route;
                final parts = route.split(' → ');
                final short = parts.isNotEmpty ? parts[0] : route;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    short.length > 6 ? '${short.substring(0, 6)}…' : short,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.gray500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.gray100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: widget.entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final val = widget.showRevenue
              ? e.revenueFcfa
              : e.bookingCount.toDouble();
          final isTouched = _touchedIndex == i;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                color: isTouched ? color : color.withValues(alpha: 0.75),
                width: isTouched ? 22 : 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxVal * 1.15,
                  color: AppColors.gray100,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
