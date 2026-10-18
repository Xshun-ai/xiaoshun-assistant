import 'dart:async';
import 'package:flutter/material.dart';

/// 自定义 Toast 提示组件
///
/// 统一短提示：深色半透明背景、语义图标、scale+opacity 动画和自动消失。
/// 新提示会立即替换旧提示，避免多个提示排队显示。
class CustomToast {
  static OverlayEntry? _overlayEntry;

  static void success(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF34C759),
      duration: duration,
    );
  }

  static void error(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFFF6B6B),
      duration: duration,
    );
  }

  static void warning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    show(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFFACC15),
      duration: duration,
    );
  }

  /// 显示自定义 Toast
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
    Color iconColor = const Color(0xFFFACC15),
    Duration duration = const Duration(milliseconds: 1800),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // 移除已有 overlay（连续触发时立即替换）
    _overlayEntry?.remove();
    _overlayEntry = null;

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _ToastOverlay(
        message: message,
        icon: icon,
        iconColor: iconColor,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          if (identical(_overlayEntry, entry)) {
            entry.remove();
            _overlayEntry = null;
          }
        },
      ),
    );

    _overlayEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _ToastOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _ToastOverlay({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.duration,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(curve);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

    _controller.forward();

    _dismissTimer = Timer(widget.duration, _startDismiss);
  }

  void _startDismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80;

    return Positioned(
      bottom: bottomPadding,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: widget.onAction == null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 40,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0E12).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: widget.iconColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null && widget.onAction != null)
                    TextButton(
                      onPressed: widget.onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: widget.iconColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(44, 36),
                      ),
                      child: Text(widget.actionLabel!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
