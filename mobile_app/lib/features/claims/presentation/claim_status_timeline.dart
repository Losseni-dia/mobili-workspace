import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Timeline verticale du statut d'une réclamation : Reçue → En cours →
/// Traitée/Rejetée. Même schéma de layout que _StopsTimeline
/// (trip_detail_page.dart) — un rail continu en fond via Stack + Positioned,
/// PAS de IntrinsicHeight/Expanded imbriqués dans une Column (piège Flutter
/// déjà rencontré et corrigé sur ce projet, voir historique).
class ClaimStatusTimeline extends StatelessWidget {
  const ClaimStatusTimeline({
    super.key,
    required this.status,
    this.createdAt,
    this.resolvedAt,
    this.resolutionMessage,
  });

  final String status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolutionMessage;

  static const double _railWidth = 24;

  bool get _isRejected => status == 'REJECTED';

  List<_TimelineStep> get _steps {
    final closedLabel = _isRejected ? 'Rejetée' : 'Traitée';
    final reached = switch (status) {
      'RECEIVED' => 1,
      'IN_PROGRESS' => 2,
      'RESOLVED' || 'REJECTED' => 3,
      _ => 1,
    };
    return [
      _TimelineStep('Reçue', createdAt, reached >= 1),
      _TimelineStep('En cours de traitement', null, reached >= 2),
      _TimelineStep(closedLabel, resolvedAt, reached >= 3, isDanger: _isRejected && reached >= 3),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Stack(
      children: [
        Positioned(
          left: _railWidth / 2 - 1,
          top: 10,
          bottom: 10,
          child: Container(width: 2, color: AppColors.gray200),
        ),
        Column(
          children: List.generate(steps.length, (i) {
            final step = steps[i];
            final isLast = i == steps.length - 1;
            final dotColor = !step.done
                ? AppColors.gray300
                : (step.isDanger ? AppColors.danger : AppColors.mobiliBlue);
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _railWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        step.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: dotColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.label,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: step.done ? AppColors.gray700 : AppColors.gray400,
                              fontWeight: step.done ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          if (step.date != null)
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(step.date!),
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400),
                            ),
                          if (isLast && step.done && (resolutionMessage?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: step.isDanger ? AppColors.dangerSoft : AppColors.mobiliBlueFog,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                resolutionMessage!,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _TimelineStep {
  const _TimelineStep(this.label, this.date, this.done, {this.isDanger = false});
  final String label;
  final DateTime? date;
  final bool done;
  final bool isDanger;
}
