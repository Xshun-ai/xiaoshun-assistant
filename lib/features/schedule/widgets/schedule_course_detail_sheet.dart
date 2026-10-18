import 'package:flutter/material.dart';

import '../../../ui/components/app_detail_info_row.dart';

/// 课程详情底部弹窗
///
/// 显示完整的课程信息，包括时间、地点、教师等
class ScheduleCourseDetailSheet extends StatelessWidget {
  final Map<String, dynamic> course;

  const ScheduleCourseDetailSheet({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部指示条
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 课程名称
          Text(
            course['course'] ?? '未知课程',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          // 详细信息列表
          _buildDetailItem(
            context,
            Icons.access_time_rounded,
            '上课时间',
            '${course['time']} (第${(course['bigPeriodIndex'] ?? 0) + 1}大节)',
          ),
          _buildDetailItem(
            context,
            Icons.calendar_today_rounded,
            '上课周次',
            '第 ${course['weeks']} 周',
          ),
          _buildDetailItem(
            context,
            Icons.location_on_rounded,
            '上课地点',
            course['location'] ?? '未知地点',
          ),
          _buildDetailItem(
            context,
            Icons.person_rounded,
            '任课教师',
            course['teacher'] ?? '未知教师',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppDetailInfoRow(
        icon: icon,
        label: label,
        value: value,
        iconBackgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        iconColor: Theme.of(context).colorScheme.primary,
        iconPadding: const EdgeInsets.all(8),
        iconRadius: 8,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
        valueStyle: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 显示课程详情弹窗
  static void show(BuildContext context, Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ScheduleCourseDetailSheet(course: course);
      },
    );
  }
}
