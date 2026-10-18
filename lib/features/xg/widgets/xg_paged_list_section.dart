import 'package:flutter/widgets.dart';

import 'xg_paged_list_footer.dart';
import 'xg_paged_sliver_list.dart';

/// 学工分页列表区块，封装列表体与尾部状态组合。
class XgPagedListSection<T> extends StatelessWidget {
  final List<T> items;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorText;
  final VoidCallback? onRetryLoadMore;
  final String? idleMessage;
  final String? noMoreMessage;
  final EdgeInsetsGeometry footerPadding;
  final double footerSpacerHeight;

  const XgPagedListSection({
    super.key,
    required this.items,
    required this.padding,
    required this.itemBuilder,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreErrorText,
    this.onRetryLoadMore,
    this.idleMessage,
    this.noMoreMessage,
    this.itemSpacing = 0,
    this.footerPadding = const EdgeInsets.symmetric(vertical: 20),
    this.footerSpacerHeight = 20,
  });

  @override
  Widget build(BuildContext context) {
    return XgPagedSliverList<T>(
      items: items,
      padding: padding,
      itemSpacing: itemSpacing,
      footer: _buildFooter(),
      itemBuilder: itemBuilder,
    );
  }

  Widget? _buildFooter() {
    if (isLoadingMore) {
      return XgPagedListFooter.loading(
        padding: footerPadding,
        spacerHeight: footerSpacerHeight,
      );
    }

    if (loadMoreErrorText != null) {
      return XgPagedListFooter.error(
        errorText: loadMoreErrorText!,
        onRetry: onRetryLoadMore ?? () {},
        padding: footerPadding,
        spacerHeight: footerSpacerHeight,
      );
    }

    if (!hasMore) {
      if (items.isNotEmpty && noMoreMessage != null) {
        return XgPagedListFooter.message(
          message: noMoreMessage!,
          padding: footerPadding,
          spacerHeight: footerSpacerHeight,
        );
      }
      return null;
    }

    if (idleMessage != null) {
      return XgPagedListFooter.message(
        message: idleMessage!,
        padding: footerPadding,
        spacerHeight: footerSpacerHeight,
      );
    }

    return XgPagedListFooter.spacer(
      spacerHeight: footerSpacerHeight,
      padding: footerPadding,
    );
  }
}
