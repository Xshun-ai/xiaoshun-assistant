import 'package:flutter/material.dart';

/// 骨架屏加载组件。
class SkeletonLoading extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoading({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey[200]!,
                Colors.grey[100]!,
                Colors.grey[200]!,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

class ScheduleSkeletonItem extends StatelessWidget {
  const ScheduleSkeletonItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoading(
                width: 60,
                height: 14,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 4),
              SkeletonLoading(
                width: 50,
                height: 12,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoading(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 8),
                SkeletonLoading(
                  width: 120,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SkeletonLoading(
            width: 50,
            height: 24,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }
}

class AnnouncementSkeletonItem extends StatelessWidget {
  const AnnouncementSkeletonItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoading(
            width: 60,
            height: 20,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoading(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonLoading(
                      width: 80,
                      height: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(width: 12),
                    SkeletonLoading(
                      width: 60,
                      height: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
