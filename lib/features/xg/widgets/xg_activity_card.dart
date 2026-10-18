import 'package:flutter/material.dart';

import '../../../models/xg_activity.dart';
import '../../../ui/components/app_meta_line.dart';
import '../../../ui/components/status_chip.dart';
import 'xg_activity_capacity_summary.dart';
import 'xg_activity_apply_widgets.dart';
import 'xg_activity_status_widgets.dart';

class XgActivityCard extends StatelessWidget {
  final XgActivity activity;
  final VoidCallback? onApply;
  final VoidCallback? onTap;

  const XgActivityCard({
    super.key,
    required this.activity,
    this.onApply,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 倒计时逻辑
    String countdownText = '';
    if (activity.effectiveCanApply) {
      final end = activity.parsedEndTime;
      if (end != null) {
        final now = DateTime.now();
        final diff = end.difference(now);
        if (!diff.isNegative) {
          if (diff.inDays > 0) {
            countdownText = '还剩 ${diff.inDays} 天';
          } else if (diff.inHours > 0) {
            countdownText = '还剩 ${diff.inHours} 小时';
          } else {
            countdownText = '即将截止';
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Level, Countdown, Status
                Row(
                  children: [
                    XgActivityLevelChip(level: activity.level),
                    const Spacer(),
                    if (countdownText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: StatusChip(
                          label: countdownText,
                          icon: Icons.access_time_rounded,
                          backgroundColor: const Color(0xFFFFF3E0),
                          foregroundColor: Colors.orange[800]!,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    XgActivityStatusPill(
                      statusDisplay: activity.statusDisplay,
                      effectiveCanApply: activity.effectiveCanApply,
                      isExpired: activity.isExpired,
                      isFull: activity.isFull,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  activity.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    letterSpacing: -0.3,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Info Rows
                _buildInfoRow(Icons.location_on_rounded, activity.location),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.calendar_today_rounded,
                  activity.timeDescription,
                ),
                const SizedBox(height: 20),
                // Bottom Row
                Row(
                  children: [
                    Expanded(
                      child: XgActivityCapacitySummary(
                        appliedCount: activity.appliedCount,
                        limitCount: activity.limitCount,
                        variant: XgActivityCapacitySummaryVariant.card,
                      ),
                    ),
                    const SizedBox(width: 20),
                    XgActivityCardActionButton(
                      activity: activity,
                      onApply: onApply,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return AppMetaLine(
      icon: icon,
      text: text,
      iconSize: 16,
      iconColor: Colors.grey[400],
      spacing: 6,
      textStyle: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.2),
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }
}
