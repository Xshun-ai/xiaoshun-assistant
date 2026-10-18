import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../../ui/states/skeleton_loading.dart';

class HomeScheduleSkeletonList extends StatelessWidget {
  const HomeScheduleSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ScheduleSkeletonItem(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingMedium),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
        const ScheduleSkeletonItem(),
      ],
    );
  }
}

/// 时间轴课程列表内容
class HomeScheduleListContent extends StatelessWidget {
  final List<Map<String, String>> courses;

  const HomeScheduleListContent({super.key, required this.courses});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(courses.length, (index) {
        final course = courses[index];
        final isLast = index == courses.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
          child: _ScheduleTimelineItem(
            time: course['time'] ?? '',
            course: course['course'] ?? '',
            location: course['location'] ?? '',
            status: course['status'] ?? '',
            isLast: isLast,
          ),
        );
      }),
    );
  }
}

/// 单节课程时间轴条目
class _ScheduleTimelineItem extends StatefulWidget {
  final String time;
  final String course;
  final String location;
  final String status;
  final bool isLast;

  const _ScheduleTimelineItem({
    required this.time,
    required this.course,
    required this.location,
    required this.status,
    required this.isLast,
  });

  @override
  State<_ScheduleTimelineItem> createState() => _ScheduleTimelineItemState();
}

class _ScheduleTimelineItemState extends State<_ScheduleTimelineItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _pingController;

  @override
  void initState() {
    super.initState();
    final isActive = !widget.status.contains('已结束');
    if (isActive) {
      _pingController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat(reverse: false);
    }
  }

  @override
  void dispose() {
    _pingController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPast = widget.status.contains('已结束');
    final isInProgress =
        widget.status.contains('上课') || widget.status.contains('进行');
    final isActive = !isPast;

    String statusLabel;
    if (isPast) {
      statusLabel = '已结束';
    } else if (isInProgress) {
      statusLabel = '上课中';
    } else {
      statusLabel = '即将开始';
    }

    final dotColor = isPast
        ? const Color(0xFFCBD5E1) // slate-300
        : const Color(0xFF2563EB); // blue-600
    final ringColor = isPast
        ? const Color(0xFFF1F5F9) // slate-100
        : const Color(0xFFDBEAFE); // blue-100
    const Color lineColor = Color(0xFFF1F5F9);

    final statusTextColor = isPast
        ? const Color(0xFF94A3B8) // slate-400
        : const Color(0xFF2563EB); // blue-600
    final statusDotColor = isPast
        ? const Color(0xFF94A3B8) // slate-400
        : const Color(0xFF3B82F6); // blue-500
    final statusBgColor = isPast
        ? const Color(0xFFE2E8F0).withValues(alpha: 0.8)
        : const Color(0xFFDBEAFE);

    final cardBgColor = isPast
        ? const Color(0xFFF8FAFC).withValues(alpha: 0.7)
        : const Color(0xFFEFF6FF).withValues(alpha: 0.4);
    final cardBorder = isActive
        ? Border.all(
            color: const Color(0xFFDBEAFE).withValues(alpha: 0.5))
        : null;

    final textColor = isPast
        ? const Color(0xFF475569) // slate-600
        : const Color(0xFF1E293B); // slate-800

    final timeBadgeBgColor = isPast
        ? const Color(0xFFE2E8F0).withValues(alpha: 0.6)
        : const Color(0xFFDBEAFE).withValues(alpha: 0.6);

    final locationIconColor = isPast
        ? const Color(0xFF94A3B8) // slate-400
        : const Color(0xFF60A5FA); // blue-400

    const Color locationPrefixColor = Color(0xFF64748B);
    final locationNameColor = isPast
        ? const Color(0xFF475569) // slate-600
        : const Color(0xFF334155); // slate-700

    const double dotSize = 18;
    const double ringWidth = 4;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间轴 — 设计稿 pl-8 (32px)
          SizedBox(
            width: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 竖线: 从当前圆点中心连到下一个圆点中心 (圆点 center = top: 12)
                // 下一项圆点 center = 12px，间距 20px → 12 + 20 = 32px 延伸
                if (!widget.isLast)
                  Positioned(
                    top: 12,
                    bottom: -32,
                    left: 15, // 居中: (32 - 2) / 2 = 15
                    child: Container(width: 2, color: lineColor),
                  ),
                // 圆点节点 (含呼吸灯) — 设计稿 absolute left-0 top-0
                Positioned(
                  top: 0,
                  left: 4,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ping 扩散光环 — 从圆心扩散再消失
                        if (isActive && _pingController != null)
                          AnimatedBuilder(
                            animation: _pingController!,
                            builder: (context, child) {
                              final t = _pingController!.value;
                              // scale: 0.5 → 2.0 (从小圆到大圆)
                              final s = 0.5 + 2.0 * t;
                              // opacity: 0.25 → 0
                              final o = 0.5 * (1 - t);
                              return Transform.scale(
                                scale: s,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF60A5FA)
                                        .withValues(alpha: o),
                                  ),
                                ),
                              );
                            },
                          ),
                        // 实心圆点 + ring
                        Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: ringColor, width: ringWidth),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 右侧内容卡片
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12),
                border: cardBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间 + 状态
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: timeBadgeBgColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActive)
                              _PulsingDot(color: statusDotColor)
                            else
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusTextColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: statusTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.course,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: locationIconColor,
                      ),
                      const SizedBox(width: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: '上课地点：',
                              style: TextStyle(
                                fontSize: 12,
                                color: locationPrefixColor,
                              ),
                            ),
                            TextSpan(
                              text: widget.location,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: locationNameColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 脉冲闪动小圆点
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + 0.7 * _controller!.value,
          child: child,
        );
      },
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
