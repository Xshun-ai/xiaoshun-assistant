import 'package:flutter/material.dart';

/// APP 顶部导航栏统一使用的文字操作入口。
class AppBarTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final String? tooltip;

  const AppBarTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? label,
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: buttonKey,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
