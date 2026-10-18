import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../ui/components/status_chip.dart';

/// 学工活动级别标签。
class XgActivityLevelChip extends StatelessWidget {
  final String level;

  const XgActivityLevelChip({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (foregroundColor, backgroundColor) = _resolveLevelColors(level);

    return StatusChip(
      label: level,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
  }
}

/// 学工活动状态胶囊。
class XgActivityStatusPill extends StatelessWidget {
  final String? statusDisplay;
  final bool effectiveCanApply;
  final bool isExpired;
  final bool isFull;
  final String applyLabel;

  const XgActivityStatusPill({
    super.key,
    required this.statusDisplay,
    required this.effectiveCanApply,
    required this.isExpired,
    required this.isFull,
    this.applyLabel = '可报名',
  });

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveStatusPresentation(
      statusDisplay: statusDisplay,
      effectiveCanApply: effectiveCanApply,
      isExpired: isExpired,
      isFull: isFull,
      applyLabel: applyLabel,
    );

    return StatusChip(
      label: resolved.label,
      backgroundColor: resolved.backgroundColor,
      foregroundColor: resolved.foregroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
  }
}

/// 学工活动状态行内展示。
class XgActivityStatusInline extends StatelessWidget {
  final String? statusDisplay;
  final bool effectiveCanApply;
  final bool isExpired;
  final bool isFull;
  final String applyLabel;

  const XgActivityStatusInline({
    super.key,
    required this.statusDisplay,
    required this.effectiveCanApply,
    required this.isExpired,
    required this.isFull,
    this.applyLabel = '报名进行中',
  });

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveStatusPresentation(
      statusDisplay: statusDisplay,
      effectiveCanApply: effectiveCanApply,
      isExpired: isExpired,
      isFull: isFull,
      applyLabel: applyLabel,
    );

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: resolved.foregroundColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          resolved.label,
          style: TextStyle(
            color: resolved.foregroundColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

(Color, Color) _resolveLevelColors(String level) {
  if (level.contains('校')) {
    return (const Color(0xFF7B1FA2), const Color(0xFFF3E5F5));
  }
  if (level.contains('院')) {
    return (const Color(0xFF2E7D32), const Color(0xFFE8F5E9));
  }
  return (AppColors.appleBlue, const Color(0xFFEBF5FF));
}

_XgStatusPresentation _resolveStatusPresentation({
  required String? statusDisplay,
  required bool effectiveCanApply,
  required bool isExpired,
  required bool isFull,
  required String applyLabel,
}) {
  if (statusDisplay != null && statusDisplay.isNotEmpty) {
    if (statusDisplay.contains('已报名') || statusDisplay.contains('通过')) {
      return const _XgStatusPresentation(
        label: '',
        foregroundColor: Color(0xFF34C759),
        backgroundColor: Color(0xFFE6F8E6),
      ).copyWithLabel(statusDisplay);
    }
    if (statusDisplay.contains('审核')) {
      return _XgStatusPresentation(
        label: statusDisplay,
        foregroundColor: Colors.orange[800]!,
        backgroundColor: const Color(0xFFFFF3E0),
      );
    }
    if (statusDisplay.contains('驳回') || statusDisplay.contains('失败')) {
      return _XgStatusPresentation(
        label: statusDisplay,
        foregroundColor: Colors.red[700]!,
        backgroundColor: const Color(0xFFFFEBEE),
      );
    }
    return const _XgStatusPresentation(
      label: '',
      foregroundColor: AppColors.appleBlue,
      backgroundColor: Color(0xFFE3F2FD),
    ).copyWithLabel(statusDisplay);
  }

  if (effectiveCanApply) {
    return _XgStatusPresentation(
      label: applyLabel,
      foregroundColor: AppColors.appleBlue,
      backgroundColor: Color(0xFFE3F2FD),
    );
  }

  var label = '不可报名';
  if (isExpired) {
    label = '已截止';
  } else if (isFull) {
    label = '已满员';
  }
  return _XgStatusPresentation(
    label: label,
    foregroundColor: Colors.grey,
    backgroundColor: const Color(0xFFF2F2F7),
  );
}

class _XgStatusPresentation {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _XgStatusPresentation({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  _XgStatusPresentation copyWithLabel(String label) {
    return _XgStatusPresentation(
      label: label,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
    );
  }
}
