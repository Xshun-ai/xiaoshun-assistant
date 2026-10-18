import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';

/// 统一的详情头部摘要块，可承载标签、标题、元信息和底部附加内容。
class AppArticleHeader extends StatelessWidget {
  final Widget? badge;
  final String title;
  final TextStyle? titleStyle;
  final List<Widget> meta;
  final double metaSpacing;
  final double metaRunSpacing;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;

  const AppArticleHeader({
    super.key,
    required this.title,
    this.badge,
    this.titleStyle,
    this.meta = const [],
    this.metaSpacing = AppSizes.paddingDefault,
    this.metaRunSpacing = AppSizes.paddingSmall,
    this.footer,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[badge!, const SizedBox(height: 14)],
          Text(
            title,
            style:
                titleStyle ??
                const TextStyle(
                  fontSize: 24,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: metaSpacing,
              runSpacing: metaRunSpacing,
              children: meta,
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}
