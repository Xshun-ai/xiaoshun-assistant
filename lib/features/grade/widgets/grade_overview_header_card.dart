import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../ui/components/app_stat_item.dart';
import '../../../ui/components/status_chip.dart';
import 'grade_summary_card.dart';

enum GradeOverviewHeaderVariant { neutral, gradient, compactGradient }

/// 成绩域业务摘要头卡。
class GradeOverviewHeaderCard extends StatelessWidget {
  final double gpa;
  final double credits;
  final int? courseCount;
  final String creditsLabel;
  final String? termLabel;
  final GradeOverviewHeaderVariant variant;

  const GradeOverviewHeaderCard({
    super.key,
    required this.gpa,
    required this.credits,
    this.courseCount,
    this.creditsLabel = '已修学分',
    this.termLabel,
    this.variant = GradeOverviewHeaderVariant.neutral,
  });

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      GradeOverviewHeaderVariant.neutral => _buildNeutral(context),
      GradeOverviewHeaderVariant.gradient => _buildGradient(context),
      GradeOverviewHeaderVariant.compactGradient => _buildCompactGradient(
        context,
      ),
    };
  }

  Widget _buildNeutral(BuildContext context) {
    final theme = Theme.of(context);

    return GradeSummaryCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.cardBackground,
      border: Border.all(color: AppColors.borderLight),
      dividerColor: AppColors.articleDivider,
      header: Row(
        children: [
          const Expanded(
            child: Text(
              '成绩摘要',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (termLabel != null)
            StatusChip(
              label: termLabel!,
              backgroundColor: AppColors.primarySoft,
              foregroundColor: theme.colorScheme.primary,
              borderColor: AppColors.primarySoftBorder,
            ),
        ],
      ),
      statItems: [
        AppStatItem(
          label: '平均绩点',
          value: gpa.toStringAsFixed(2),
          valueStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        AppStatItem(
          label: creditsLabel,
          value: credits.toStringAsFixed(1),
          valueStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        AppStatItem(
          label: '课程数量',
          value: (courseCount ?? 0).toString(),
          valueStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGradient(BuildContext context) {
    final theme = Theme.of(context);

    return GradeSummaryCard(
      gradient: LinearGradient(
        colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: 24,
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      dividerColor: Colors.white24,
      statItems: [
        _buildWhiteStatItem('平均绩点', gpa.toStringAsFixed(2)),
        _buildWhiteStatItem(creditsLabel, credits.toStringAsFixed(1)),
        _buildWhiteStatItem('课程数量', (courseCount ?? 0).toString()),
      ],
    );
  }

  Widget _buildCompactGradient(BuildContext context) {
    final theme = Theme.of(context);

    return GradeSummaryCard(
      gradient: LinearGradient(
        colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: theme.primaryColor.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      dividerColor: Colors.white30,
      statItems: [
        AppStatItem(
          label: '平均绩点',
          value: gpa.toStringAsFixed(2),
          valueStyle: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        AppStatItem(
          label: creditsLabel,
          value: credits.toStringAsFixed(1),
          valueStyle: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  AppStatItem _buildWhiteStatItem(String label, String value) {
    return AppStatItem(
      label: label,
      value: value,
      valueStyle: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 12,
      ),
    );
  }
}
