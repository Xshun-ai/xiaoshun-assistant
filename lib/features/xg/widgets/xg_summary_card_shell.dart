import 'package:flutter/material.dart';

/// 综测相关页面共用的摘要卡壳层。
class XgSummaryCardShell extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry? padding;

  const XgSummaryCardShell({
    super.key,
    required this.child,
    this.accentColor = const Color(0xFF6A11CB),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}
