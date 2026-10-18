import 'package:flutter/material.dart';

import '../../../services/campus_access_service.dart';
import '../../../services/xg_activity_service.dart';
import '../../../models/xg_activity.dart';
import '../../../ui/components/app_bar_text_action.dart';
import 'xg_activity_card.dart';
import 'xg_filter_header.dart';
import 'xg_paged_list_section.dart';
import 'xg_sliver_page_app_bar.dart';

class XgActivityMyActivitiesAction extends StatelessWidget {
  final GlobalKey anchorKey;
  final VoidCallback onTap;

  const XgActivityMyActivitiesAction({
    super.key,
    required this.anchorKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBarTextAction(
      label: '报名记录',
      tooltip: '报名记录',
      buttonKey: anchorKey,
      onPressed: onTap,
    );
  }
}

class XgActivityFilterSection extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool isToday;
  final DateTimeRange? dateRange;
  final String searchScopeText;
  final VoidCallback onAllTap;
  final VoidCallback onTodayTap;
  final VoidCallback onDateTap;

  const XgActivityFilterSection({
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
    return SliverPersistentHeader(
      pinned: true,
      delegate: XgFilterHeaderDelegate(
        height: 150,
        child: XgFilterContent(
          searchController: searchController,
          onSearchChanged: onSearchChanged,
          isToday: isToday,
          dateRange: dateRange,
          searchScopeText: searchScopeText,
          onAllTap: onAllTap,
          onTodayTap: onTodayTap,
          onDateTap: onDateTap,
        ),
      ),
    );
  }
}

class XgActivityListSliver extends StatelessWidget {
  final List<XgActivity> activities;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorText;
  final GlobalKey Function(String activityId) activityCardKeyBuilder;
  final void Function(XgActivity activity) onApply;
  final Future<void> Function(XgActivity activity) onOpenDetail;
  final VoidCallback onRetryLoadMore;

  const XgActivityListSliver({
    super.key,
    required this.activities,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreErrorText,
    required this.activityCardKeyBuilder,
    required this.onApply,
    required this.onOpenDetail,
    required this.onRetryLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return XgPagedListSection<XgActivity>(
      items: activities,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      loadMoreErrorText: loadMoreErrorText,
      noMoreMessage: activities.isNotEmpty ? '没有更多活动了' : null,
      onRetryLoadMore: onRetryLoadMore,
      itemBuilder: (context, activity, index) {
        return XgActivityCard(
          key: activityCardKeyBuilder(activity.id),
          activity: activity,
          onApply: () => onApply(activity),
          onTap: () => onOpenDetail(activity),
        );
      },
    );
  }
}

class XgActivityErrorSliver extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const XgActivityErrorSliver({
    super.key,
    required this.error,
    required this.onRetry,
  });

  String _resolveListErrorMessage() {
    if (CampusAccessService.isCampusNetworkUnavailableError(error) ||
        error.contains('CampusServiceUnavailableException') ||
        error.contains(XgActivityService.campusUnavailableMessage)) {
      return '校园网服务暂不可用，请稍后重试';
    }
    return '加载失败，请稍后重试';
  }

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 72,
                color: Colors.orange[300],
              ),
              const SizedBox(height: 16),
              Text(
                _resolveListErrorMessage(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '下拉或点击重试后会重新请求最新数据',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

class XgActivityEmptySliver extends StatelessWidget {
  const XgActivityEmptySliver({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无活动', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

Widget buildXgActivityAppBar({
  required GlobalKey anchorKey,
  required VoidCallback onMyActivitiesTap,
}) {
  return XgSliverPageAppBar(
    title: '活动报名',
    actions: [
      XgActivityMyActivitiesAction(
        anchorKey: anchorKey,
        onTap: onMyActivitiesTap,
      ),
    ],
  );
}
