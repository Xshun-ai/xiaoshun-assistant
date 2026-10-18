import 'package:flutter/material.dart';

import '../../../ui/components/app_sliver_page_app_bar.dart';

/// 学工页面共用的 SliverAppBar 壳层。
class XgSliverPageAppBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const XgSliverPageAppBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppSliverPageAppBar(title: title, actions: actions);
  }
}
