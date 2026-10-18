import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../components/app_card.dart';

/// 页面顶部摘要卡，承接轻量欢迎信息或资料摘要。
class SummaryHeaderCard extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;
  final String? eyebrow;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final List<Widget> meta;
  final Widget? footer;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final double? borderRadius;

  const SummaryHeaderCard({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.eyebrow,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.meta = const [],
    this.footer,
    this.contentPadding,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      border: border ?? Border.all(color: AppColors.borderLight),
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
      borderRadius: borderRadius,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: contentPadding ?? const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSizes.paddingDefault),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null) ...[
                        Text(
                          eyebrow!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        title,
                        style:
                            titleStyle ??
                            const TextStyle(
                              fontSize: 22,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          style:
                              subtitleStyle ??
                              const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSizes.paddingDefault),
                  trailing!,
                ],
              ],
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: AppSizes.paddingLarge),
              Wrap(
                spacing: AppSizes.paddingSmall,
                runSpacing: AppSizes.paddingSmall,
                children: meta,
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: AppSizes.paddingDefault),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
