import 'package:flutter/material.dart';

import '../../../services/grade_service.dart';

class GradeExpandableCourseCard extends StatelessWidget {
  final ThemeData theme;
  final Grade grade;

  const GradeExpandableCourseCard({
    super.key,
    required this.theme,
    required this.grade,
  });

  @override
  Widget build(BuildContext context) {
    final isPass = grade.isPassed;
    final scoreVal = double.tryParse(grade.score) ?? 0;
    final isExcellent = isPass && scoreVal >= 90;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPass
                  ? (isExcellent
                        ? Colors.amber.shade100
                        : theme.colorScheme.primaryContainer)
                  : theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              grade.score,
              style: TextStyle(
                color: isPass
                    ? (isExcellent
                          ? Colors.amber.shade900
                          : theme.colorScheme.onPrimaryContainer)
                    : theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          title: Text(
            grade.courseName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (grade.attribute.isNotEmpty)
                  _GradeTag(theme: theme, text: grade.attribute),
                if (grade.attribute.isNotEmpty) const SizedBox(width: 8),
                Text(
                  '${grade.credit}学分',
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GradeDetailItem(
                    theme: theme,
                    label: '绩点',
                    value: grade.gpa.toString(),
                  ),
                  _GradeDetailItem(
                    theme: theme,
                    label: '性质',
                    value: grade.nature,
                  ),
                  _GradeDetailItem(
                    theme: theme,
                    label: '考核',
                    value: grade.examType,
                  ),
                  _GradeDetailItem(
                    theme: theme,
                    label: '状态',
                    value: isPass ? '合格' : '挂科',
                    color: isPass ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GradeCompactCourseCard extends StatelessWidget {
  final ThemeData theme;
  final Grade grade;
  final int index;

  const GradeCompactCourseCard({
    super.key,
    required this.theme,
    required this.grade,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grade.courseName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (grade.attribute.isNotEmpty)
                          _GradeTag(theme: theme, text: grade.attribute),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GradeDetailItem(
                  theme: theme,
                  label: '成绩',
                  value: grade.score,
                ),
              ),
              Expanded(
                child: _GradeDetailItem(
                  theme: theme,
                  label: '绩点',
                  value: grade.gpa.toStringAsFixed(2),
                ),
              ),
              Expanded(
                child: _GradeDetailItem(
                  theme: theme,
                  label: '学分',
                  value: grade.credit.toStringAsFixed(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradeTag extends StatelessWidget {
  final ThemeData theme;
  final String text;

  const _GradeTag({required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _GradeDetailItem extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final String value;
  final Color? color;

  const _GradeDetailItem({
    required this.theme,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? theme.textTheme.bodyMedium?.color ?? Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
