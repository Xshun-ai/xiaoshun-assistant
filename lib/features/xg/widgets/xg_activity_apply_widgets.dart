import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../models/xg_activity.dart';

/// 学工活动列表卡中的操作按钮。
class XgActivityCardActionButton extends StatelessWidget {
  final XgActivity activity;
  final VoidCallback? onApply;

  const XgActivityCardActionButton({
    super.key,
    required this.activity,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final hasStatus =
        activity.statusDisplay != null && activity.statusDisplay!.isNotEmpty;
    if (hasStatus) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            activity.statusDisplay!,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final canApply = activity.effectiveCanApply;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canApply
              ? [AppColors.appleBlue, const Color(0xFF00C7BE)]
              : [Colors.grey[300]!, Colors.grey[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: canApply
            ? [
                BoxShadow(
                  color: AppColors.appleBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canApply ? onApply : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  canApply ? '立即报名' : '不可报名',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 学工活动详情页底部操作栏。
class XgActivityDetailBottomBar extends StatelessWidget {
  final bool isApplied;
  final bool isExpired;
  final bool isFull;
  final String? cannotApplyReason;
  final VoidCallback onApply;

  const XgActivityDetailBottomBar({
    super.key,
    required this.isApplied,
    required this.isExpired,
    required this.isFull,
    required this.cannotApplyReason,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final action = _resolveAction();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: action.enabled ? action.onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: action.backgroundColor,
              disabledBackgroundColor: action.backgroundColor,
              foregroundColor: action.foregroundColor,
              disabledForegroundColor: action.foregroundColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text(action.label),
          ),
        ),
      ),
    );
  }

  _DetailAction _resolveAction() {
    if (isApplied) {
      return _DetailAction(
        label: '已报名',
        backgroundColor: const Color(0xFFF2F2F7),
        foregroundColor: Colors.grey[600]!,
        enabled: false,
        onPressed: null,
      );
    }

    if (cannotApplyReason != null && cannotApplyReason!.isNotEmpty) {
      final reasonStr = cannotApplyReason!;
      var label = reasonStr;
      if (reasonStr.toLowerCase() == 'true') {
        if (isExpired) {
          label = '已截止';
        } else if (isFull) {
          label = '已满员';
        } else {
          label = '不可报名';
        }
      }
      return _DetailAction(
        label: label,
        backgroundColor: const Color(0xFFF2F2F7),
        foregroundColor: Colors.grey[600]!,
        enabled: false,
        onPressed: null,
      );
    }

    if (!isExpired && !isFull) {
      return const _DetailAction(
        label: '立即报名',
        backgroundColor: Color(0xFF007AFF),
        foregroundColor: Colors.white,
        enabled: true,
      ).copyWith(onPressed: onApply);
    }

    return _DetailAction(
      label: isExpired ? '已截止' : '不可报名',
      backgroundColor: const Color(0xFFF2F2F7),
      foregroundColor: Colors.grey[600]!,
      enabled: false,
      onPressed: null,
    );
  }
}

class _DetailAction {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool enabled;
  final VoidCallback? onPressed;

  const _DetailAction({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.enabled,
    this.onPressed,
  });

  _DetailAction copyWith({VoidCallback? onPressed}) {
    return _DetailAction(
      label: label,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      enabled: enabled,
      onPressed: onPressed ?? this.onPressed,
    );
  }
}
