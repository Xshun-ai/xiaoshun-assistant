import 'package:flutter/material.dart';

import '../../constants/app_sizes.dart';

/// 统一的轻量胶囊标签。
class StatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final FontWeight? fontWeight;

  const StatusChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.borderColor,
    this.padding,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingSmall,
            vertical: AppSizes.paddingTiny,
          ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: fontSize ?? 12,
              fontWeight: fontWeight ?? FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
