import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../components/app_card.dart';

/// 统一的详情区块卡片，用于正文、附件、回复等标题 + 内容结构。
class AppDetailSectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final bool showShadow;
  final double headerBottomSpacing;
  final TextStyle? titleStyle;

  const AppDetailSectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.showShadow = false,
    this.headerBottomSpacing = 14,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || trailing != null;

    return AppCard(
      margin: margin ?? EdgeInsets.zero,
      showShadow: showShadow,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      border: Border.all(color: borderColor ?? AppColors.borderLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style:
                          titleStyle ??
                          const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                if (trailing != null) ...[
                  if (title != null) const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            SizedBox(height: headerBottomSpacing),
          ],
          child,
        ],
      ),
    );
  }
}
