import 'package:flutter/material.dart';

import '../../../ui/components/status_chip.dart';

/// 功能卡片组件 - 用于功能Tab展示各种服务功能
class FeatureCard extends StatelessWidget {
  /// 图标
  final IconData icon;

  /// 标题
  final String title;

  /// 副标题/描述
  final String subtitle;

  /// 图标背景色
  final Color color;

  /// 点击回调
  final VoidCallback onTap;

  final String? badgeText;

  final IconData? trailingIcon;

  /// 是否处于点击后的打开中状态
  final bool isLoading;

  /// 是否可用（不可用时显示灰色状态）
  final bool isActive;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeText,
    this.trailingIcon,
    this.isLoading = false,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = isActive;
    final canTap = !isLoading;
    final displayColor = isActive ? color : Colors.grey;
    final resolvedBadgeText = badgeText;

    Color withOpacityCompat(Color color, double opacity) {
      return color.withValues(alpha: opacity);
    }

    return Material(
      color: isEnabled ? Colors.white : Colors.grey[50],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: canTap ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isEnabled ? Colors.white : Colors.grey[50],
            border: Border.all(color: withOpacityCompat(Colors.grey, 0.06)),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: withOpacityCompat(Colors.black, 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: withOpacityCompat(displayColor, 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: displayColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isLoading
                                ? displayColor
                                : isEnabled
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLoading ? '正在打开...' : subtitle,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                      ),
                    )
                  else if (!isActive)
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: Colors.grey[400],
                    )
                  else if (trailingIcon != null)
                    Icon(trailingIcon, size: 16, color: Colors.grey[700]),
                ],
              ),
              if (resolvedBadgeText != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: StatusChip(
                    label: resolvedBadgeText,
                    backgroundColor: withOpacityCompat(displayColor, 0.12),
                    foregroundColor: displayColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
