import 'package:flutter/material.dart';

/// 成绩域通用摘要卡。
class GradeSummaryCard extends StatelessWidget {
  final Widget? header;
  final List<Widget> statItems;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final double borderRadius;
  final Color dividerColor;
  final double headerBottomSpacing;

  const GradeSummaryCard({
    super.key,
    required this.statItems,
    this.header,
    this.padding = const EdgeInsets.all(24),
    this.gradient,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.borderRadius = 20,
    required this.dividerColor,
    this.headerBottomSpacing = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            header!,
            SizedBox(height: headerBottomSpacing),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int index = 0; index < statItems.length; index++) ...[
                Expanded(child: Center(child: statItems[index])),
                if (index != statItems.length - 1)
                  Container(width: 1, height: 40, color: dividerColor),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
