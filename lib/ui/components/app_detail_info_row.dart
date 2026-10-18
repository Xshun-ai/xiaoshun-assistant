import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// 带图标块的详情信息行，适合详情页和弹窗中的键值展示。
class AppDetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconBackgroundColor;
  final Color iconColor;
  final EdgeInsetsGeometry? iconPadding;
  final double iconSize;
  final double iconRadius;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final double spacing;

  const AppDetailInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBackgroundColor,
    required this.iconColor,
    this.iconPadding,
    this.iconSize = 20,
    this.iconRadius = 12,
    this.labelStyle,
    this.valueStyle,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: iconPadding ?? const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(iconRadius),
          ),
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    labelStyle ??
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style:
                    valueStyle ??
                    const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
