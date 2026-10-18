import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

enum XgActivityCapacitySummaryVariant { card, detail }

/// 学工活动的人数 / 名额 / 进度摘要块。
class XgActivityCapacitySummary extends StatelessWidget {
  final int appliedCount;
  final int? limitCount;
  final XgActivityCapacitySummaryVariant variant;

  const XgActivityCapacitySummary({
    super.key,
    required this.appliedCount,
    required this.limitCount,
    this.variant = XgActivityCapacitySummaryVariant.card,
  });

  @override
  Widget build(BuildContext context) {
    final isDetail = variant == XgActivityCapacitySummaryVariant.detail;
    final progress = limitCount != null && limitCount! > 0
        ? (appliedCount / limitCount!).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _leadingText(),
              style: TextStyle(
                fontSize: isDetail ? 13 : 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _trailingText(),
              style: TextStyle(
                fontSize: isDetail ? 13 : 12,
                color: isDetail ? Colors.grey[600] : Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildProgress(progress),
      ],
    );
  }

  String _leadingText() {
    if (variant == XgActivityCapacitySummaryVariant.detail) {
      return limitCount != null ? '名额剩余 ${limitCount! - appliedCount}' : '名额不限';
    }
    return '已报名 $appliedCount';
  }

  String _trailingText() {
    if (variant == XgActivityCapacitySummaryVariant.detail) {
      return limitCount != null
          ? '$appliedCount / $limitCount'
          : '$appliedCount 人已报名';
    }
    return limitCount != null ? '限额 $limitCount' : '不限人数';
  }

  Widget _buildProgress(double progress) {
    final isDetail = variant == XgActivityCapacitySummaryVariant.detail;
    final progressBackgroundColor = isDetail
        ? const Color(0xFFF5F7FA)
        : const Color(0xFFF2F2F7);
    final minHeight = isDetail ? 8.0 : 6.0;

    if (limitCount != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: progressBackgroundColor,
          valueColor: AlwaysStoppedAnimation(
            isDetail && progress >= 1.0 ? Colors.red : AppColors.appleBlue,
          ),
          minHeight: minHeight,
        ),
      );
    }

    if (isDetail) {
      return const SizedBox.shrink();
    }

    return Container(
      height: minHeight,
      decoration: BoxDecoration(
        color: progressBackgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
