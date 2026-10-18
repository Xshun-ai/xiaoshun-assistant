import 'package:flutter/material.dart';
import '../../../services/schedule_service.dart';

/// 课程表周次选择器
///
/// 显示一个底部弹窗，让用户选择要查看的周次
class ScheduleWeekPicker extends StatelessWidget {
  final int currentWeek;
  final int selectedWeek;
  final int maxWeek;
  final bool showAllOption; // 是否显示"全部"选项
  final Function(int) onWeekSelected;
  final List<ScheduleTerm> terms;
  final String? selectedTermId;
  final ValueChanged<ScheduleTerm> onTermSelected;

  const ScheduleWeekPicker({
    super.key,
    required this.currentWeek,
    required this.selectedWeek,
    required this.maxWeek,
    required this.onWeekSelected,
    required this.terms,
    required this.selectedTermId,
    required this.onTermSelected,
    this.showAllOption = false,
  });

  @override
  Widget build(BuildContext context) {
    // 总项目数 = "全部"选项(可选) + 周次数
    final int totalCount = maxWeek + (showAllOption ? 1 : 0);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '选择学期和周次',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (terms.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '学期',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: terms.map((term) {
                  final isSelected = term.id == selectedTermId;
                  return ChoiceChip(
                    label: Text(term.name),
                    selected: isSelected,
                    onSelected: (_) {
                      if (!isSelected) {
                        Navigator.pop(context);
                        onTermSelected(term);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              currentWeek > 0 ? '周次（当前：第$currentWeek周）' : '周次',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemCount: totalCount,
              itemBuilder: (context, index) {
                // 第一项为"全部"（如果启用）
                if (showAllOption && index == 0) {
                  final isSelected = selectedWeek == 0;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      if (selectedWeek != 0) {
                        onWeekSelected(0);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: !isSelected
                            ? Border.all(color: Colors.orange[300]!)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '全部',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                final week = showAllOption ? index : index + 1;
                final isSelected = week == selectedWeek;
                final isCurrent = week == currentWeek;

                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    if (week != selectedWeek) {
                      onWeekSelected(week);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : (isCurrent
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent && !isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$week',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.black87),
                        fontWeight: isSelected || isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 显示周次选择器
  static void show(
    BuildContext context, {
    required int currentWeek,
    required int selectedWeek,
    required int maxWeek,
    required Function(int) onWeekSelected,
    required List<ScheduleTerm> terms,
    required String? selectedTermId,
    required ValueChanged<ScheduleTerm> onTermSelected,
    bool showAllOption = false,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ScheduleWeekPicker(
          currentWeek: currentWeek,
          selectedWeek: selectedWeek,
          maxWeek: maxWeek,
          onWeekSelected: onWeekSelected,
          terms: terms,
          selectedTermId: selectedTermId,
          onTermSelected: onTermSelected,
          showAllOption: showAllOption,
        );
      },
    );
  }
}
