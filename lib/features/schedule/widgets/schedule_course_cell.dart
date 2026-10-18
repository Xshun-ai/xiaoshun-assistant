import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// 课程单元格组件
/// 
/// 显示课程表中的单个课程格子，包括课程名称、地点、教师等信息
class ScheduleCourseCell extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  const ScheduleCourseCell({
    super.key,
    required this.course,
    required this.onTap,
  });

  /// 获取课程莫兰迪配色
  Color _getCourseColor(String courseName) {
    if (courseName.isEmpty) return AppColors.courseColors[0];
    final index = courseName.hashCode.abs() % AppColors.courseColors.length;
    return AppColors.courseColors[index];
  }

  @override
  Widget build(BuildContext context) {
    if (course.isEmpty) {
      // 空格子，显示极淡的边框
      return Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Colors.grey.withValues(alpha: 0.05),
              width: 1,
            ),
            bottom: BorderSide(
              color: Colors.grey.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
      );
    }

    final courseName = course['course'] ?? '';
    final location = course['location'] ?? '';
    final teacher = course['teacher'] ?? '';

    // 获取课程对应的柔和背景色
    final bgColor = _getCourseColor(courseName);
    final textColor = Colors.black87;
    final subTextColor = Colors.black54;

    // 使用 RepaintBoundary 隔离重绘，避免影响相邻单元格
    return RepaintBoundary(
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.6),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            // 课程名称
            Expanded(
              child: Text(
                courseName,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                  letterSpacing: 0.1,
                ),
              ),
            ),

            // 地点信息
            if (location.isNotEmpty) ...[
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_rounded, size: 10, color: subTextColor),
                  const SizedBox(width: 1),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 教师信息
            if (teacher.isNotEmpty) ...[
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 10,
                    color: subTextColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: Text(
                      teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        color: subTextColor.withValues(alpha: 0.7),
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
