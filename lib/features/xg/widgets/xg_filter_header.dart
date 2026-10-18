import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class XgFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  XgFilterHeaderDelegate({required this.height, required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant XgFilterHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

class XgFilterContent extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool isToday;
  final DateTimeRange? dateRange;
  final String searchScopeText;
  final VoidCallback onAllTap;
  final VoidCallback onTodayTap;
  final VoidCallback onDateTap;

  const XgFilterContent({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.isToday,
    required this.dateRange,
    required this.searchScopeText,
    required this.onAllTap,
    required this.onTodayTap,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA).withValues(alpha: 0.95), // 半透明背景
      child: ClipRRect(
        // For BackdropFilter if needed, or just container
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 搜索框
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '搜索活动名称...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 过滤器 Chips
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        label: '近期热门',
                        isSelected: !isToday && dateRange == null,
                        icon: Icons.local_fire_department_rounded,
                        onTap: onAllTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        label: '今日活动',
                        isSelected: isToday,
                        icon: Icons.today_rounded,
                        onTap: onTodayTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        label: dateRange == null
                            ? '日期筛选'
                            : '${DateFormat('MM/dd').format(dateRange!.start)}-${DateFormat('MM/dd').format(dateRange!.end)}',
                        isSelected: dateRange != null,
                        icon: Icons.calendar_month_rounded,
                        onTap: onDateTap,
                      ),
                    ),
                  ],
                ),
                // 搜索范围提示
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        searchScopeText,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 8,
          ), // Reduced horizontal padding
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF007AFF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF007AFF)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center content
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                // Allow text to shrink if needed
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
