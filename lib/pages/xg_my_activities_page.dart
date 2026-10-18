import 'package:flutter/material.dart';
import '../models/xg_activity_record.dart';
import '../models/xg_activity.dart';
import '../services/campus_access_service.dart';
import '../services/log_service.dart';
import '../services/xg_activity_service.dart';
import '../utils/loadable_state.dart';
import '../constants/app_colors.dart';
import '../features/xg/pages/xg_activity_detail_page.dart';
import '../features/xg/widgets/xg_activity_record_card.dart';
import '../features/xg/widgets/xg_paged_list_section.dart';
import '../features/xg/widgets/xg_sliver_page_app_bar.dart';
import '../ui/components/custom_toast.dart';

class XgMyActivitiesPage extends StatefulWidget {
  const XgMyActivitiesPage({super.key});

  @override
  State<XgMyActivitiesPage> createState() => _XgMyActivitiesPageState();
}

class _XgMyActivitiesPageState extends State<XgMyActivitiesPage>
    with LoadableStateMixin {
  static const String _campusUnavailableMessage = '校园网不可用，请连接校园网后重试';
  // Pagination State
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  final ScrollController _scrollController = ScrollController();
  final XgActivityService _activityService = XgActivityService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initPage();
  }

  Future<void> _initPage() async {
    await _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final loadable = getLoadable<List<XgActivityRecord>>('records');
      if (!loadable.loading && !_isLoadingMore && _hasMore) {
        _loadData(loadMore: true);
      }
    }
  }

  Future<void> _loadData({
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      // 加载更多时不使用Mixin，直接处理
      setState(() => _isLoadingMore = true);

      try {
        final page = _currentPage + 1;
        final result = await _activityService.fetchMyActivities(page: page);

        if (mounted) {
          setState(() {
            final records =
                getLoadable<List<XgActivityRecord>>('records').data ?? [];
            records.addAll(result.records);
            updateLoadable('records', LoadableData.success(records));
            _currentPage++;
            _hasMore = result.records.length >= 10; // 假设每页10条
            _isLoadingMore = false;
          });
        }
      } catch (e) {
        final msg = e.toString();
        await LogService().log('智慧学工', '加载更多失败: $msg');
        final userMessage =
            CampusAccessService.isCampusNetworkUnavailableError(e) ||
                e is CampusServiceUnavailableException
            ? _campusUnavailableMessage
            : '获取失败，请稍后重试';

        if (mounted) {
          setState(() => _isLoadingMore = false);
          CustomToast.error(context, message: userMessage);
        }
      }
    } else {
      // 首次加载使用Mixin
      await loadData<List<XgActivityRecord>>(
        key: 'records',
        loader: () async {
          final result = await _activityService.fetchMyActivities(page: 1);
          _currentPage = 1;
          _hasMore = result.records.length >= 10;
          return result.records;
        },
      );
    }
  }

  Future<void> _navigateToDetail(XgActivityRecord record) async {
    // 创建一个临时的 XgActivity 对象用于传递 ID
    final dummyActivity = XgActivity(
      id: record.activityId,
      name: record.activityName,
      location: '加载中...',
      timeDescription: '...',
      level: record.typeDisplay,
      appliedCount: 0,
      canApply: false,
      startTime: '',
      endTime: '',
    );

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => XgActivityDetailPage(activity: dummyActivity),
      ),
    );

    if (changed == true && mounted) {
      await _loadData(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: buildLoadable<List<XgActivityRecord>>(
        key: 'records',
        errorMessage: _campusUnavailableMessage,
        builder: (records) {
          return RefreshIndicator(
            onRefresh: () => _loadData(forceRefresh: true),
            color: AppColors.appleBlue,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [_buildSliverAppBar(), _buildActivityList(records)],
            ),
          );
        },
        emptyMessage: '暂无活动记录',
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return const XgSliverPageAppBar(title: '我的活动');
  }

  Widget _buildActivityList(List<XgActivityRecord> records) {
    return XgPagedListSection<XgActivityRecord>(
      items: records,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemSpacing: 12,
      hasMore: _hasMore,
      isLoadingMore: _isLoadingMore,
      idleMessage: _hasMore ? '加载更多...' : null,
      footerPadding: const EdgeInsets.all(16),
      itemBuilder: (context, record, index) {
        return XgActivityRecordCard(
          record: record,
          onTap: () => _navigateToDetail(record),
        );
      },
    );
  }
}
