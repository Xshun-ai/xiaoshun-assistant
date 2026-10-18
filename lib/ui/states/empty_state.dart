import 'package:flutter/material.dart';

import '../../constants/app_sizes.dart';

/// 统一空状态组件。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? description;
  final double? iconSize;
  final Color? iconColor;
  final double? fontSize;
  final Color? textColor;
  final bool inListView;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.description,
    this.iconSize,
    this.iconColor,
    this.fontSize,
    this.textColor,
    this.inListView = false,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize ?? 80.0, color: iconColor ?? Colors.grey),
        const SizedBox(height: AppSizes.paddingDefault),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize ?? 16.0,
            color: textColor ?? Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSizes.paddingSmall),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey[600],
            ),
          ),
        ],
        if (actionText != null && onAction != null) ...[
          const SizedBox(height: AppSizes.paddingDefault),
          FilledButton.tonal(onPressed: onAction, child: Text(actionText!)),
        ],
      ],
    );

    if (inListView) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(child: content),
      );
    }

    return Center(child: content);
  }
}
