import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/xg_activity.dart';
import '../services/xg_activity_service.dart';
import '../services/campus_access_service.dart';
import '../services/log_service.dart';
import '../utils/role_helper.dart';
import '../utils/loadable_state.dart';
import '../constants/app_colors.dart';
import '../features/xg/pages/xg_activity_detail_page.dart';
import '../features/xg/widgets/xg_activity_apply_dialog.dart';
import '../features/xg/widgets/xg_action_feedback.dart';
import '../features/xg/widgets/xg_activity_page_sections.dart';
import '../ui/overlays/guide_bubble.dart';
import '../ui/components/custom_toast.dart';
import 'xg_my_activities_page.dart';

class XgActivityPage extends StatefulWidget {
  const XgActivityPage({super.key});

  @override
  State<XgActivityPage> createState() => _XgActivityPageState();
}

class _XgActivityPageState extends State<XgActivityPage>
    with SingleTickerProviderStateMixin, LoadableStateMixin {
  static const String _campusUnavailableMessage = '校园网服务暂不可用，请稍后重试';
  static const double _estimatedActivityCardExtent = 320;
  static const int _defaultPageSize = 20;
  static const String _myActivitiesGuideDisabledKey =
      'xg_activity_my_activities_guide_disabled';

  // Pagination State
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _loadMoreError;

  // Filters
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isToday = false;
  DateTimeRange? _dateRange;

  // Scroll Controller for UI effects
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _activityCardKeys = {};
  final GlobalKey _myActivitiesButtonKey = GlobalKey();

  // 活动服务实例
  final XgActivityService _activityService = XgActivityService();
  GuideBubbleController? _myActivitiesGuideController;

  bool _shouldAutoScrollToTodayAvailable = false;
  bool _isAutoScrollingToTodayAvailable = false;
  bool _didAutoScrollToTodayAvailable = false;
  bool _hasShownTodayUnavailableHint = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initPage();
  }

  Future<void> _initPage() async {
    if (!mounted) return;
    await _loadData();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowMyActivitiesGuide();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _myActivitiesGuideController?.dismiss();
    _myActivitiesGuideController = null;
    _scrollController.dispose(); // Listener is disposed with controller
    super.dispose();
  }

  Future<void> _maybeShowMyActivitiesGuide() async {
    try {
      if (!mounted) return;

      await _waitForNextFrame();
      if (!mounted) return;

      _myActivitiesGuideController?.dismiss();
      final controller = await showAnchoredGuideBubble(
        anchorKey: _myActivitiesButtonKey,
        disablePreferenceKey: _myActivitiesGuideDisabledKey,
        title: '这里是“我的活动”',
        message: '活动报名与报名记录都在这里查看。',
        icon: Icons.history_edu_rounded,
        accentColor: const Color(0xFF2563EB),
      );
      if (!mounted) {
        controller?.dismiss();
        return;
      }
      _myActivitiesGuideController = controller;
    } catch (e) {
      await LogService().log('活动报名', '展示我的活动首次引导失败: $e');
    }
  }

  void _removeMyActivitiesGuide() {
    _myActivitiesGuideController?.dismiss();
    _myActivitiesGuideController = null;
  }

  void _openMyActivities() {
    _removeMyActivitiesGuide();
    LogService().log('页面访问', '打开功能: 我的活动');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const XgMyActivitiesPage()),
    );
  }

  Future<void> _openActivityDetail(XgActivity activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => XgActivityDetailPage(activity: activity),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final loadable = getLoadable<List<XgActivity>>('activities');
      if (!loadable.loading && !_isLoadingMore && _hasMore) {
        _loadData(loadMore: true);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData();
    });
  }

  void _resetTodayAutoScrollState({required bool enable}) {
    _shouldAutoScrollToTodayAvailable = enable;
    _isAutoScrollingToTodayAvailable = false;
    _didAutoScrollToTodayAvailable = false;
    _hasShownTodayUnavailableHint = false;
  }

  GlobalKey _getActivityCardKey(String activityId) {
    return _activityCardKeys.putIfAbsent(
      activityId,
      () => GlobalKey(debugLabel: 'activity-card-$activityId'),
    );
  }

  int _findFirstAvailableTodayActivityIndex(List<XgActivity> activities) {
    for (int i = 0; i < activities.length; i++) {
      if (activities[i].effectiveCanApply) {
        return i;
      }
    }
    return -1;
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<void> _scrollToActivityCard({
    required String activityId,
    required int index,
  }) async {
    await _waitForNextFrame();
    if (!mounted || !_scrollController.hasClients) return;

    final roughOffset =
        ((index * _estimatedActivityCardExtent) - _estimatedActivityCardExtent)
            .clamp(0.0, _scrollController.position.maxScrollExtent);

    if ((roughOffset - _scrollController.offset).abs() > 48) {
      await _scrollController.animateTo(
        roughOffset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }

    await _waitForNextFrame();
    if (!mounted) return;

    var targetContext = _activityCardKeys[activityId]?.currentContext;
    if (targetContext == null) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    final currentTargetContext = _activityCardKeys[activityId]?.currentContext;
    if (currentTargetContext == null || !currentTargetContext.mounted) return;

    await Scrollable.ensureVisible(
      currentTargetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _maybeAutoScrollToTodayAvailableActivity({
    List<XgActivity>? seedActivities,
  }) async {
    if (!_isToday ||
        !_shouldAutoScrollToTodayAvailable ||
        _didAutoScrollToTodayAvailable ||
        _isAutoScrollingToTodayAvailable ||
        !mounted) {
      return;
    }

    _isAutoScrollingToTodayAvailable = true;
    try {
      var activities =
          seedActivities ??
          getLoadable<List<XgActivity>>('activities').data ??
          <XgActivity>[];

      while (mounted && _isToday) {
        final targetIndex = _findFirstAvailableTodayActivityIndex(activities);
        if (targetIndex >= 0) {
          final targetActivity = activities[targetIndex];
          _didAutoScrollToTodayAvailable = true;
          _shouldAutoScrollToTodayAvailable = false;
          await _scrollToActivityCard(
            activityId: targetActivity.id,
            index: targetIndex,
          );
          await LogService().log(
            '筛选操作',
            '今日活动自动定位到可报名活动: ${targetActivity.name}',
          );
          return;
        }

        if (!_hasMore) break;

        final previousCount = activities.length;
        await _loadData(loadMore: true);
        activities =
            getLoadable<List<XgActivity>>('activities').data ?? <XgActivity>[];

        if (_loadMoreError != null || activities.length <= previousCount) {
          break;
        }
      }

      _shouldAutoScrollToTodayAvailable = false;
      if (!_hasShownTodayUnavailableHint && mounted) {
        _hasShownTodayUnavailableHint = true;
        CustomToast.show(context, message: '今日暂无可报名活动，已为你显示今日活动列表');
      }
    } finally {
      _isAutoScrollingToTodayAvailable = false;
    }
  }

  Future<void> _loadData({
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      // 加载更多时不使用Mixin，直接处理
      setState(() {
        _isLoadingMore = true;
        _loadMoreError = null;
      });

      try {
        final requestParams = _buildRequestParams(_currentPage + 1);
        final result = await _activityService.fetchAvailableActivities(
          requestParams,
        );

        if (mounted) {
          setState(() {
            final activities =
                getLoadable<List<XgActivity>>('activities').data ?? [];
            activities.addAll(result.activities);
            updateLoadable('activities', LoadableData.success(activities));
            _currentPage++;

            // 判断是否还有更多
            if (result.totalCount > 0) {
              _hasMore = activities.length < result.totalCount;
            } else {
              _hasMore = result.activities.length >= 20;
            }

            _isLoadingMore = false;
            _loadMoreError = null;
          });
        }
      } catch (e, stackTrace) {
        debugPrint('Error loading more activities: $e');
        await LogService().log('智慧学工', '加载更多失败: $e\nStack: $stackTrace');
        final message =
            CampusAccessService.isCampusNetworkUnavailableError(e) ||
                e is CampusServiceUnavailableException
            ? _campusUnavailableMessage
            : '加载失败，请检查网络或重试';
        if (mounted) {
          setState(() {
            _loadMoreError = message;
            _isLoadingMore = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _loadMoreError = null;
        });
      }
      // 首次加载使用Mixin
      await loadData<List<XgActivity>>(
        key: 'activities',
        loader: () async {
          final requestParams = _buildRequestParams(1);
          final result = await _activityService.fetchAvailableActivities(
            requestParams,
          );

          // 重置分页状态
          _currentPage = 1;
          if (result.totalCount > 0) {
            _hasMore = result.activities.length < result.totalCount;
          } else {
            _hasMore = result.activities.length >= 20;
          }

          await LogService().log(
            '智慧学工',
            '加载活动列表成功: ${result.activities.length}条',
          );
          return result.activities;
        },
        onSuccess: (data) async {
          if (_isToday) {
            _maybeAutoScrollToTodayAvailableActivity(seedActivities: data);
          }
        },
        onError: (error) async {
          await LogService().log('智慧学工', '加载活动列表异常: $error');
        },
      );
    }
  }

  /// 构造请求参数
  Map<String, dynamic> _buildRequestParams(
    int pageNum, {
    int pageSize = _defaultPageSize,
    String? searchKeyword,
  }) {
    Map<String, dynamic> params = {"PAGESIZE": pageSize, "PAGENUM": pageNum};
    final resolvedSearchKeyword =
        searchKeyword ?? _searchController.text.trim();

    if (resolvedSearchKeyword.isNotEmpty) {
      params["HDMC"] = resolvedSearchKeyword;

      // 如果正在搜索且没有选择特定时间范围，则默认搜索未来半年的活动
      if (!_isToday && _dateRange == null) {
        final now = DateTime.now();
        params["BEGINDATE"] = DateFormat('yyyy-MM-dd').format(now);
        params["ENDDATE"] = DateFormat('yyyy-MM-dd')
            .format(now.add(const Duration(days: 180)));
      }
    }

    if (_dateRange != null) {
      params["BEGINDATE"] = _dateRange!.start.toString().split(' ')[0];
      params["ENDDATE"] = _dateRange!.end.toString().split(' ')[0];
    }

    if (_isToday) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      params["BEGINDATE"] = today;
      params["ENDDATE"] = today;
    }

    return params;
  }

  Future<void> _doApply(
    String activityId,
    String cycd, {
    String? activityName,
  }) async {
    showXgActionLoadingDialog(context);

    final roleName = getRoleName(cycd);

    final result = await _activityService.applyForActivity(
      activityId: activityId,
      cycd: cycd,
      activityName: activityName,
      roleName: roleName,
      scene: '列表页',
    );

    if (!mounted) return;

    hideXgActionLoadingDialog(context);

    if (result.success) {
      showXgSuccessSnackBar(context, message: '报名成功！');
      _loadData(forceRefresh: true);
    } else {
      showXgErrorSnackBar(context, message: result.message);
    }
  }

  Future<void> _applyForActivity(XgActivity activity) async {
    if (!mounted) return;

    final selectedRole = await showXgActivityApplyDialog(
      context: context,
      activity: activity,
    );

    if (!mounted || selectedRole == null) {
      return;
    }

    _doApply(activity.id, selectedRole, activityName: activity.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            buildXgActivityAppBar(
              anchorKey: _myActivitiesButtonKey,
              onMyActivitiesTap: _openMyActivities,
            ),
            XgActivityFilterSection(
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              isToday: _isToday,
              dateRange: _dateRange,
              searchScopeText: _getSearchScopeText(),
              onAllTap: () {
                setState(() {
                  _isToday = false;
                  _dateRange = null;
                  _resetTodayAutoScrollState(enable: false);
                });
                LogService().log('筛选操作', '用户切换筛选: 近期热门');
                _loadData();
              },
              onTodayTap: () {
                setState(() {
                  _isToday = true;
                  _dateRange = null;
                  _resetTodayAutoScrollState(enable: true);
                });
                LogService().log('筛选操作', '用户切换筛选: 今日活动');
                _loadData();
              },
              onDateTap: _pickCustomDateRange,
            ),
            _buildActivityList(),
          ],
        ),
      ),
    );
  }

  String _getSearchScopeText() {
    if (_isToday) {
      return '当前搜索范围：今日活动';
    }
    if (_dateRange != null) {
      final start = DateFormat('MM/dd').format(_dateRange!.start);
      final end = DateFormat('MM/dd').format(_dateRange!.end);
      return '当前搜索范围：$start - $end';
    }
    if (_searchController.text.isNotEmpty) {
      return '当前搜索范围：未来半年内的所有活动';
    }
    return '当前显示：近期热门推荐活动';
  }

  Widget _buildActivityList() {
    return buildLoadable<List<XgActivity>>(
      key: 'activities',
      loadingBuilder: () => const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.appleBlue),
        ),
      ),
      errorBuilder: (error) => XgActivityErrorSliver(
        error: error,
        onRetry: () => _loadData(forceRefresh: true),
      ),
      emptyMessage: '暂无活动',
      emptyBuilder: () => const XgActivityEmptySliver(),
      builder: (activities) => XgActivityListSliver(
        activities: activities,
        hasMore: _hasMore,
        isLoadingMore: _isLoadingMore,
        loadMoreErrorText: _loadMoreError,
        activityCardKeyBuilder: _getActivityCardKey,
        onApply: _applyForActivity,
        onOpenDetail: _openActivityDetail,
        onRetryLoadMore: () {
          setState(() {
            _loadMoreError = null;
          });
          _loadData(loadMore: true);
        },
      ),
    );
  }

  void _pickCustomDateRange() async {
    // 用户点击“日期筛选”时，直接进入自定义日期范围选择，减少干扰项
    LogService().log('筛选操作', '用户点击筛选: 日期筛选');

    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 180)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      helpText: '选择日期范围',
      confirmText: '确定',
      cancelText: '取消',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.appleBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) {
      LogService().log('筛选操作', '用户取消选择日期范围');
      return;
    }

    setState(() {
      _dateRange = picked;
      _isToday = false;
      _resetTodayAutoScrollState(enable: false);
    });

    final begin = DateFormat('yyyy-MM-dd').format(picked.start);
    final end = DateFormat('yyyy-MM-dd').format(picked.end);
    LogService().log('筛选操作', '用户选择日期范围: $begin ~ $end');
    _loadData();
  }
}
