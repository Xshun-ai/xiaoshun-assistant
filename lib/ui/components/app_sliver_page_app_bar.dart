import 'package:flutter/material.dart';

/// APP 滚动页面统一使用的 Sliver 标题栏。
class AppSliverPageAppBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const AppSliverPageAppBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    // 为 actions 统一添加右边距，避免按钮紧贴屏幕右侧
    final wrappedActions = actions.isNotEmpty
        ? [
            ...actions,
            const SizedBox(width: 12),
          ]
        : actions;

    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: true,
      centerTitle: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      actions: wrappedActions,
    );
  }
}
