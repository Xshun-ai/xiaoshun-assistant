import 'package:flutter/material.dart';
import '../../../models/portal_announcement.dart';
import '../../../services/campus_access_service.dart';
import '../../../services/log_service.dart';
import '../../../services/home_data_service.dart';
import '../../../utils/loadable_state.dart';
import '../../schedule_page.dart';
import '../../../features/home/widgets/home_notice_widgets.dart';
import '../../../features/home/widgets/home_portal_announcement_widgets.dart';
import '../../../features/home/widgets/home_schedule_widgets.dart';
import '../../portal_announcements_list_page.dart';
import '../../portal_announcement_detail_page.dart';
import '../../../features/campus_map/campus_map_page.dart';

/// 首页Tab - 显示今日课程、校园通知等核心信息
class HomeTab extends StatefulWidget {
  final int refreshTick;

  const HomeTab({
    super.key,
    required this.refreshTick,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab>
    with
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver,
        LoadableStateMixin {
  String _displayName = '';
  final HomeDataService _dataService = HomeDataService();
  bool _backgroundRefreshScheduled = false;
  bool _backgroundRefreshInProgress = false;
  DateTime? _lastBackgroundRefreshAt;
  static const Duration _backgroundRefreshDebounce = Duration(seconds: 3);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScheduleData();
    _loadDisplayName();
    _loadPortalAnnouncements();
  }

  /// 检查页面是否活跃并触发后台刷新
  void _checkAndRefresh() {
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      if (_backgroundRefreshScheduled || _backgroundRefreshInProgress) return;
      final lastRefreshAt = _lastBackgroundRefreshAt;
      if (lastRefreshAt != null &&
          DateTime.now().difference(lastRefreshAt) <
              _backgroundRefreshDebounce) {
        return;
      }

      _backgroundRefreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _backgroundRefreshScheduled = false;
        _backgroundRefresh();
      });
    }
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _checkAndRefresh();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // 当Widget树重新组装时（例如热重载），也检查是否需要刷新
    _checkAndRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRefresh();
    }
  }

  /// 后台刷新：无感刷新今日课程和校园通知
  Future<void> _backgroundRefresh() async {
    if (_backgroundRefreshInProgress) return;
    _backgroundRefreshInProgress = true;
    _lastBackgroundRefreshAt = DateTime.now();
    debugPrint('[首页后台刷新] 页面变为活跃状态，开始后台刷新');
    try {
      await LogService().log('首页', '页面变为活跃状态，触发后台刷新');
      await Future.wait([
        _initScheduleData(),
        _loadPortalAnnouncements(),
      ], eagerError: false);

      debugPrint('[首页后台刷新] 后台刷新完成');
    } finally {
      _backgroundRefreshInProgress = false;
    }
  }

  /// 下拉刷新：重新加载今日课程和校园通知
  Future<void> _handleRefresh() async {
    debugPrint('[首页刷新] 用户触发下拉刷新');
    await LogService().log('首页', '用户下拉刷新首页数据');
    await Future.wait([
      _initScheduleData(),
      _loadPortalAnnouncements(),
    ]);

    debugPrint('[首页刷新] 刷新完成');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadDisplayName() async {
    final name = await _dataService.loadDisplayName();

    if (mounted && name != null && name.isNotEmpty) {
      setState(() {
        _displayName = name;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      return '早上好';
    } else if (hour >= 11 && hour < 13) {
      return '中午好';
    } else if (hour >= 13 && hour < 19) {
      return '下午好';
    } else {
      return '晚上好';
    }
  }

  String _formatName() {
    if (_displayName.isEmpty) return '同学';

    // 如果是中文名，取第一个字（姓）
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(_displayName[0])) {
      return '${_displayName[0]}同学';
    }

    // 英文名或其他，直接显示
    return '$_displayName同学';
  }

  /// 初始化课表数据
  /// 优先加载今日课程快速缓存,然后后台刷新
  Future<void> _initScheduleData() async {
    await loadData<List<Map<String, String>>>(
      key: 'schedule',
      cacheLoader: () => _dataService.loadScheduleCached(),
      loader: () => _dataService.loadScheduleFresh(),
      onError: (error) async {
        await LogService().log('课表', '首页加载课表失败: $error');
        debugPrint('课表加载失败: $error');
      },
    );
  }

  /// 加载融合门户公告（5秒超时，静默失败）
  Future<void> _loadPortalAnnouncements() async {
    await loadData<List<PortalAnnouncement>>(
      key: 'portalAnnouncements',
      cacheLoader: () => _dataService.loadPortalAnnouncementsCached(),
      loader: () => _dataService.loadPortalAnnouncementsFresh(),
      onError: (error) async {
        // 静默失败,不阻塞用户体验
        await LogService().log('融合门户', '首页加载公告失败: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: primaryColor,
        backgroundColor: Colors.white,
        displacement: 40,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              _buildGradientHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  children: [
                    _buildScheduleSection(),
                    const SizedBox(height: 20),
                    _buildAnnouncementsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return buildLoadable<List<Map<String, String>>>(
      key: 'schedule',
      skeletonBuilder: () => const HomeScheduleSkeletonList(),
      emptyMessage: '今天没有课哦 ~',
      errorBuilder: (error) {
        if (CampusAccessService.isCampusNetworkUnavailableError(error) ||
            error is CampusServiceUnavailableException) {
          return const Center(
            child: HomeNoticeCard(
              icon: Icons.cloud_off_rounded,
              title: '校园网服务暂不可用',
              subtitle: '请稍后下拉刷新课表数据',
              color: Colors.orange,
              dense: true,
            ),
          );
        }
        return Center(
          child: Text('获取课表失败', style: TextStyle(color: Colors.grey[600])),
        );
      },
      builder: (courses) {
        return HomeScheduleListContent(courses: courses);
      },
    );
  }

  /// 构建融合门户公告列表
  Widget _buildPortalAnnouncementsList() {
    return buildLoadable<List<PortalAnnouncement>>(
      key: 'portalAnnouncements',
      skeletonBuilder: () => const HomePortalAnnouncementsSkeletonList(),
      emptyMessage: '暂无公告',
      errorBuilder: (error) {
        if (CampusAccessService.isCampusNetworkUnavailableError(error) ||
            error is CampusServiceUnavailableException) {
          return const Center(
            child: HomeNoticeCard(
              icon: Icons.cloud_off_rounded,
              title: '校园网服务暂不可用',
              subtitle: '请稍后下拉刷新查看门户公告',
              color: Colors.orange,
              dense: true,
            ),
          );
        }
        // 特殊处理校园网连接失败的情况
        return const Center(
          child: HomeNoticeCard(
            icon: Icons.wifi_off_rounded,
            title: '无法连接到校园网',
            subtitle: '请连接校园WiFi或VPN后查看公告',
            color: Colors.orange,
            dense: true,
          ),
        );
      },
      builder: (announcements) {
        return HomePortalAnnouncementsListContent(
          announcements: announcements,
          onTap: (announcement) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PortalAnnouncementDetailPage(announcement: announcement),
              ),
            );
          },
        );
      },
    );
  }

  /// 渐变头部区域
  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF4338CA)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 20),
          _buildQuickActionsBar(),
        ],
      ),
    );
  }

  /// 头部问候语 + 通知铃铛
  Widget _buildHeaderRow() {
    final now = DateTime.now();
    const weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${now.year}年${now.month}月${now.day}日 星期${weekDays[now.weekday - 1]}',
                style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF)),
              ),
              const SizedBox(height: 4),
              Text(
                '${_getGreeting()}，${_formatName()}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        _buildNotificationBell(),
      ],
    );
  }

  /// 通知铃铛按钮
  Widget _buildNotificationBell() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PortalAnnouncementsListPage(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Center(
                child: Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 快捷入口栏
  Widget _buildQuickActionsBar() {
    final actions = <_QuickAction>[
      _QuickAction('校园地图', Icons.map_outlined),
      _QuickAction('校园通知', Icons.campaign_outlined),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((item) {
          return GestureDetector(
            onTap: () {
              if (item.name == '校园地图') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CampusMapPage(),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const PortalAnnouncementsListPage(),
                  ),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 带标题行的白色卡片 section header
  Widget _buildSectionHeader({
    required String title,
    required Color accentColor,
    String? actionText,
    VoidCallback? onAction,
    Color? pillBackgroundColor,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const Spacer(),
        if (actionText != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: pillBackgroundColor != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pillBackgroundColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionText,
                          style: TextStyle(
                            fontSize: 12,
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 14, color: accentColor),
                      ],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionText,
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 14, color: accentColor),
                    ],
                  ),
          ),
      ],
    );
  }

  /// 课程表卡片分区
  Widget _buildScheduleSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: '今日课程表',
            accentColor: const Color(0xFF2563EB),
            actionText: '查看完整课表',
            pillBackgroundColor: const Color(0xFFEFF6FF),
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SchedulePage()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildScheduleList(),
        ],
      ),
    );
  }

  /// 公告通知卡片分区
  Widget _buildAnnouncementsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: '校园公告通知',
            accentColor: const Color(0xFFF97316),
            actionText: '更多',
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PortalAnnouncementsListPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildPortalAnnouncementsList(),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String name;
  final IconData icon;
  const _QuickAction(this.name, this.icon);
}
