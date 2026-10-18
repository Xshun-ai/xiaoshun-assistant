import 'package:flutter/material.dart';

import '../../../models/xg_activity.dart';
import '../../../ui/components/app_detail_info_row.dart';
import '../../../ui/patterns/summary_header_card.dart';
import 'xg_activity_capacity_summary.dart';
import 'xg_activity_status_widgets.dart';

/// 学工活动详情页顶部摘要卡。
class XgActivityDetailTitleCard extends StatelessWidget {
  final XgActivity activity;
  final Map<String, dynamic> detail;

  const XgActivityDetailTitleCard({
    super.key,
    required this.activity,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final int applied =
        int.tryParse(detail['CJRS']?.toString() ?? '') ?? activity.appliedCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SummaryHeaderCard(
        leading: XgActivityLevelChip(level: activity.level),
        trailing: XgActivityStatusInline(
          statusDisplay: detail['SHZT_DISPLAY'] ?? activity.statusDisplay,
          effectiveCanApply: activity.effectiveCanApply,
          isExpired: activity.isExpired,
          isFull: activity.isFull,
        ),
        title: activity.name,
        titleStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.4,
          color: Colors.black87,
        ),
        footer: XgActivityCapacitySummary(
          appliedCount: applied,
          limitCount: activity.limitCount,
          variant: XgActivityCapacitySummaryVariant.detail,
        ),
        contentPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.white,
        border: null,
        borderRadius: 20,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}

/// 学工活动详情页信息卡。
class XgActivityDetailInfoCard extends StatelessWidget {
  final XgActivity activity;
  final Map<String, dynamic> detail;

  const XgActivityDetailInfoCard({
    super.key,
    required this.activity,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.calendar_today_rounded,
            '开始时间',
            detail['HDKSSJ'] ?? activity.timeDescription,
            const Color(0xFFE0F7FA),
            const Color(0xFF00BCD4),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.event_available_rounded,
            '结束时间',
            detail['HDJSSJ'] ?? activity.endTime,
            const Color(0xFFFFF3E0),
            Colors.orange[800]!,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF5F7FA)),
          ),
          _buildInfoRow(
            Icons.location_on_rounded,
            '活动地点',
            detail['HDDD_DISPLAY'] ?? activity.location,
            const Color(0xFFE3F2FD),
            const Color(0xFF007AFF),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color bg,
    Color iconColor,
  ) {
    return AppDetailInfoRow(
      icon: icon,
      label: label,
      value: value,
      iconBackgroundColor: bg,
      iconColor: iconColor,
    );
  }
}

/// 学工活动详情页描述卡。
class XgActivityDescriptionCard extends StatelessWidget {
  final String description;

  const XgActivityDescriptionCard({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '活动详情',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.8,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
