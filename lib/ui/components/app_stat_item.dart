import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// 统一的垂直统计项。
class AppStatItem extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;
  final double spacing;

  const AppStatItem({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textAlign = TextAlign.center,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          value,
          textAlign: textAlign,
          style:
              valueStyle ??
              const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: spacing),
        Text(
          label,
          textAlign: textAlign,
          style:
              labelStyle ??
              const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
