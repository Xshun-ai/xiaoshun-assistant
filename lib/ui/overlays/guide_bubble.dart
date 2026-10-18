import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuideBubbleController {
  GuideBubbleController({
    required VoidCallback dismiss,
    required Future<void> Function() disablePermanently,
  }) : _dismiss = dismiss,
       _disablePermanently = disablePermanently;

  final VoidCallback _dismiss;
  final Future<void> Function() _disablePermanently;

  bool _dismissed = false;

  void dismiss() {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    _dismiss();
  }

  Future<void> disablePermanently() async {
    await _disablePermanently();
  }
}

Future<GuideBubbleController?> showAnchoredGuideBubble({
  required GlobalKey anchorKey,
  required String disablePreferenceKey,
  required String title,
  required String message,
  required IconData icon,
  required Color accentColor,
  String actionLabel = '不再提示',
  Duration autoDismiss = const Duration(seconds: 5),
  double width = 260,
  double horizontalMargin = 16,
  double verticalOffset = 10,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(disablePreferenceKey) == true) {
    return null;
  }

  final currentContext = anchorKey.currentContext;
  if (currentContext == null || !currentContext.mounted) {
    return null;
  }

  final overlay = Overlay.maybeOf(currentContext);
  final mediaQuery = MediaQuery.maybeOf(currentContext);
  if (overlay == null || mediaQuery == null) {
    return null;
  }

  final renderBox = currentContext.findRenderObject();
  if (renderBox is! RenderBox) {
    return null;
  }

  final targetOffset = renderBox.localToGlobal(Offset.zero);
  final targetSize = renderBox.size;
  final screenWidth = mediaQuery.size.width;
  final bubbleWidth = math.min(
    width,
    math.max(0.0, screenWidth - horizontalMargin * 2),
  );
  final left = (targetOffset.dx + targetSize.width - bubbleWidth).clamp(
    horizontalMargin,
    screenWidth - bubbleWidth - horizontalMargin,
  );

  OverlayEntry? entry;
  Timer? dismissTimer;

  void dismissOverlay() {
    dismissTimer?.cancel();
    dismissTimer = null;
    entry?.remove();
    entry = null;
  }

  late final GuideBubbleController controller;

  Future<void> disablePermanently() async {
    await prefs.setBool(disablePreferenceKey, true);
    controller.dismiss();
  }

  controller = GuideBubbleController(
    dismiss: dismissOverlay,
    disablePermanently: disablePermanently,
  );

  entry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: controller.dismiss,
          ),
        ),
        Positioned(
          left: left,
          top: targetOffset.dy + targetSize.height + verticalOffset,
          child: Material(
            color: Colors.transparent,
            child: _GuideBubbleCard(
              width: bubbleWidth,
              title: title,
              message: message,
              icon: icon,
              accentColor: accentColor,
              actionLabel: actionLabel,
              onDontShowAgain: () {
                unawaited(controller.disablePermanently());
              },
            ),
          ),
        ),
      ],
    ),
  );

  overlay.insert(entry!);
  dismissTimer = Timer(autoDismiss, controller.dismiss);
  return controller;
}

class _GuideBubbleCard extends StatelessWidget {
  const _GuideBubbleCard({
    required this.width,
    required this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.actionLabel,
    required this.onDontShowAgain,
  });

  final double width;
  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final String actionLabel;
  final VoidCallback onDontShowAgain;

  static const Color _backgroundColor = Color(0xFF0F172A);
  static const Color _bodyColor = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          transform: Matrix4.rotationZ(0.78),
        ),
        Transform.translate(
          offset: const Offset(0, -6),
          child: Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: const TextStyle(
                              color: _bodyColor,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: onDontShowAgain,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
