import 'package:flutter/widgets.dart';

/// 学工页共用的分页 Sliver 列表区块。
class XgPagedSliverList<T> extends StatelessWidget {
  final List<T> items;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? footer;

  const XgPagedSliverList({
    super.key,
    required this.items,
    required this.padding,
    required this.itemBuilder,
    this.itemSpacing = 0,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final hasFooter = footer != null;

    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (hasFooter && index == items.length) {
            return footer!;
          }

          final child = itemBuilder(context, items[index], index);
          if (itemSpacing <= 0) {
            return child;
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : itemSpacing,
            ),
            child: child,
          );
        }, childCount: items.length + (hasFooter ? 1 : 0)),
      ),
    );
  }
}
