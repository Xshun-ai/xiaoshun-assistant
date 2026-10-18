import 'package:flutter/material.dart';

/// 课程表同步滚动表头
/// 
/// 显示星期和日期，并与课程表主体保持横向滚动同步
class ScheduleSyncHeader extends StatefulWidget {
  final double columnWidth;
  final List<Map<String, String>> weekDates;
  final ScrollController scrollController;
  final bool isCurrentWeek;
  final bool hideDates; // 开学前模式下隐藏日期

  const ScheduleSyncHeader({
    super.key,
    required this.columnWidth,
    required this.weekDates,
    required this.scrollController,
    this.isCurrentWeek = false,
    this.hideDates = false,
  });

  @override
  State<ScheduleSyncHeader> createState() => _ScheduleSyncHeaderState();
}

class _ScheduleSyncHeaderState extends State<ScheduleSyncHeader> {
  final ScrollController _localController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 监听外部控制器的滚动，同步到本地
    widget.scrollController.addListener(_onExternalScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onExternalScroll);
    _localController.dispose();
    super.dispose();
  }

  void _onExternalScroll() {
    if (_localController.hasClients && widget.scrollController.hasClients) {
      if (_localController.offset != widget.scrollController.offset) {
        _localController.jumpTo(widget.scrollController.offset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _localController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), // 禁止用户直接滚动 Header
      child: Row(
        children: List.generate(7, (index) => _buildDayHeader(context, index)),
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, int dayIndex) {
    final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final today = DateTime.now();
    // 只有在当前周，并且是今天时才高亮
    final isToday = widget.isCurrentWeek && ((dayIndex + 1) == today.weekday);
    
    String dateText = '';
    if (!widget.hideDates && widget.weekDates.isNotEmpty) {
      final dateItem = widget.weekDates.firstWhere(
        (e) => (int.tryParse(e['id'] ?? '0') ?? 0) == (dayIndex + 1),
        orElse: () => {},
      );
      if (dateItem.isNotEmpty) {
        final dateStr = dateItem['date'] ?? '';
        if (dateStr.length >= 10) {
          dateText = dateStr.substring(8, 10); // 只显示日期部分
        } else {
          dateText = dateStr;
        }
      }
    }

    return Container(
      width: widget.columnWidth,
      height: 40,
      alignment: Alignment.center,
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isToday ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekDays[dayIndex],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? Colors.white : Colors.black54,
              ),
            ),
            if (dateText.isNotEmpty)
              Text(
                dateText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isToday ? Colors.white : Colors.black87,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
