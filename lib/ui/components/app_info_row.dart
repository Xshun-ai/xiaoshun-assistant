import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';

/// 统一的信息行组件。
class AppInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final double? labelWidth;
  final bool dense;
  final bool multiline;
  final bool expandValue;
  final TextAlign valueAlign;
  final EdgeInsetsGeometry? padding;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.labelWidth,
    this.dense = false,
    this.multiline = false,
    this.expandValue = true,
    this.valueAlign = TextAlign.right,
    this.padding,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final verticalPadding = dense ? 8.0 : 14.0;
    final resolvedLabelStyle =
        labelStyle ??
        const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        );
    final resolvedValueStyle =
        valueStyle ??
        const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 4),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingSmall),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              child: Icon(icon, size: 18, color: primaryColor),
            ),
            const SizedBox(width: AppSizes.paddingDefault),
          ],
          if (labelWidth != null)
            SizedBox(
              width: labelWidth,
              child: Text(label, style: resolvedLabelStyle),
            )
          else
            Text(label, style: resolvedLabelStyle),
          const SizedBox(width: AppSizes.paddingDefault),
          if (expandValue)
            Expanded(
              child: Text(
                value,
                textAlign: valueAlign,
                maxLines: multiline ? null : 1,
                overflow: multiline ? null : TextOverflow.ellipsis,
                style: resolvedValueStyle,
              ),
            )
          else
            Text(
              value,
              textAlign: valueAlign,
              maxLines: multiline ? null : 1,
              overflow: multiline ? null : TextOverflow.ellipsis,
              style: resolvedValueStyle,
            ),
        ],
      ),
    );
  }
}
