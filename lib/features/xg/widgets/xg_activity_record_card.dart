import 'package:flutter/material.dart';

import '../../../models/xg_activity_record.dart';
import '../../../ui/components/app_meta_line.dart';
import '../../../ui/components/status_chip.dart';

class XgActivityRecordCard extends StatelessWidget {
  final XgActivityRecord record;
  final VoidCallback onTap;

  const XgActivityRecordCard({
    super.key,
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 状态颜色逻辑
    final (statusColor, statusBgColor) = _getStatusColors();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      record.activityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    label: record.statusText,
                    backgroundColor: statusBgColor,
                    foregroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppMetaLine(
                icon: Icons.access_time_rounded,
                text: '申请时间: ${record.applyTime}',
                iconSize: 14,
                iconColor: Colors.grey[400],
                textStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                expanded: false,
              ),
              if (record.typeDisplay != '无') ...[
                const SizedBox(height: 6),
                AppMetaLine(
                  icon: Icons.category_outlined,
                  text: record.typeDisplay,
                  iconSize: 14,
                  iconColor: Colors.grey[400],
                  textStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  expanded: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _getStatusColors() {
    if (record.isFinished) {
      return (Colors.grey[600]!, Colors.grey[100]!);
    } else if (record.auditStatusDisplay.contains('无需') ||
        record.auditStatusDisplay.contains('通过')) {
      return (const Color(0xFF4CAF50), const Color(0xFFE8F5E9));
    } else {
      return (const Color(0xFFFF9800), const Color(0xFFFFF3E0));
    }
  }
}
