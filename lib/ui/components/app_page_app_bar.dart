import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// APP 普通二级页面统一顶部标题栏。
///
/// 页面只需要传入标题即可，返回按钮由 Flutter 根据路由栈自动显示，
/// 保证公告、设置等页面保持一致。
class AppPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Widget? leading;
  final bool? automaticallyImplyLeading;

  const AppPageAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.backgroundColor,
    this.leading,
    this.automaticallyImplyLeading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // 为 actions 统一添加右边距，避免按钮紧贴屏幕右侧
    final wrappedActions = actions != null
        ? [
            ...actions!,
            const SizedBox(width: 12),
          ]
        : null;

    return AppBar(
      title:
          titleWidget ??
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
      centerTitle: true,
      backgroundColor: backgroundColor ?? Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading ?? true,
      actions: wrappedActions,
    );
  }
}
