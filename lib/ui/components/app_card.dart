import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';

/// 通用应用卡片组件。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final double? borderRadius;
  final bool showShadow;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.showShadow = true,
    this.backgroundColor,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? AppSizes.radiusLarge;

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppSizes.paddingDefault),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        border: border,
        boxShadow:
            boxShadow ??
            (showShadow
                ? [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: AppSizes.shadowBlur,
                      offset: const Offset(0, AppSizes.shadowOffset),
                    ),
                  ]
                : null),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        child: onTap != null
            ? InkWell(
                borderRadius: BorderRadius.circular(effectiveBorderRadius),
                onTap: onTap,
                child: Padding(
                  padding:
                      padding ?? const EdgeInsets.all(AppSizes.paddingDefault),
                  child: child,
                ),
              )
            : Padding(
                padding:
                    padding ?? const EdgeInsets.all(AppSizes.paddingDefault),
                child: child,
              ),
      ),
    );
  }
}
