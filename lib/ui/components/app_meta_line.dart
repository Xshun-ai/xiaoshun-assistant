import 'package:flutter/material.dart';

/// 统一的图标 + 文本元信息行。
class AppMetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final double iconSize;
  final Color? iconColor;
  final double spacing;
  final TextStyle? textStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final bool expanded;
  final CrossAxisAlignment crossAxisAlignment;

  const AppMetaLine({
    super.key,
    required this.icon,
    required this.text,
    this.iconSize = 14,
    this.iconColor,
    this.spacing = 4,
    this.textStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.expanded = true,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: textStyle,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.visible : overflow,
    );

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        SizedBox(width: spacing),
        if (expanded) Expanded(child: textWidget) else textWidget,
      ],
    );
  }
}
