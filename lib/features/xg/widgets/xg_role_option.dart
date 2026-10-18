import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

/// 智慧学工活动报名 - 角色选择选项组件
///
/// 用于活动报名时显示可选择的角色卡片（参与者、组织者、观众等）
/// 支持选中/未选中状态的视觉反馈
class XgRoleOption extends StatelessWidget {
  /// 角色标题（如：参与者、组织者）
  final String title;

  /// 角色副标题描述（如：作为普通参与人员加入）
  final String subtitle;

  /// 当前角色的值（用于单选逻辑）
  final String value;

  /// 当前选中的角色值
  final String groupValue;

  /// 角色图标
  final IconData icon;

  /// 角色选择变更回调
  final ValueChanged<String> onChanged;

  const XgRoleOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightBlueBackground : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.appleBlue : AppColors.borderGray,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.appleBlue
                    : AppColors.containerGray,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.appleBlue : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.appleBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
