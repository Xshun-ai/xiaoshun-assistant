import 'package:flutter/material.dart';
import '../models/portal_announcement.dart';
import '../services/campus_access_service.dart';
import '../services/portal_announcement_service.dart';
import '../services/log_service.dart';
import '../ui/states/empty_state.dart';
import '../ui/components/app_page_app_bar.dart';
import '../ui/states/retry_error_state.dart';
import 'portal_announcement_detail_page.dart';

/// 融合门户全部公告列表页面
class PortalAnnouncementsListPage extends StatefulWidget {
  const PortalAnnouncementsListPage({super.key});

  @override
  State<PortalAnnouncementsListPage> createState() =>
      _PortalAnnouncementsListPageState();
}

class _PortalAnnouncementsListPageState
    extends State<PortalAnnouncementsListPage> {
  final _service = PortalAnnouncementService();
  final List<PortalAnnouncement> _announcements = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _scrollController.addListener(_onScroll);
    _logPageView();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听 - 实现无感分页
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  /// 加载公告列表（首次加载）
  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = null;
    });

    try {
      await _service.init();
      final data = await _service.fetchAnnouncements(page: 1);

      if (mounted) {
        setState(() {
          _announcements.clear();
          _announcements.addAll(data);
          _isLoading = false;
          _hasMore = data.length >= 20; // 如果返回的数据少于20条，说明没有更多了
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = CampusAccessService.isCampusNetworkUnavailableError(e)
              ? '校园网服务暂不可用，请稍后重试'
              : '加载失败，请稍后重试';
        });
      }
    }
  }

  /// 加载更多
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      final data = await _service.fetchAnnouncements(page: _currentPage);

      if (mounted) {
        setState(() {
          _announcements.addAll(data);
          _isLoadingMore = false;
          _hasMore = data.length >= 20;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--; // 加载失败，回退页码
        });
        if (_announcements.isEmpty) {
          setState(() {
            _errorMessage =
                CampusAccessService.isCampusNetworkUnavailableError(e)
                ? '校园网服务暂不可用，请稍后重试'
                : '加载失败，请稍后重试';
          });
        }
      }
    }
  }

  /// 记录页面访问日志
  Future<void> _logPageView() async {
    await LogService().log('融合门户公告', '查看全部公告列表');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: const AppPageAppBar(title: '学生公告'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null && _announcements.isEmpty && !_isLoading) {
      return RetryErrorState(
        title: _errorMessage ?? '校园网服务暂不可用，请稍后重试',
        message: '公告列表暂时无法加载',
        helperText: '下拉或点击重试后会重新请求最新数据',
        buttonText: '重试',
        onRetry: _loadAnnouncements,
        iconColor: Colors.orange[300],
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_announcements.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _announcements.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _announcements.length) {
            // 加载更多指示器
            return _buildLoadingMoreIndicator();
          }

          final announcement = _announcements[index];
          return _buildAnnouncementCard(announcement);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const EmptyState(
          icon: Icons.notifications_off_outlined,
          message: '暂无公告',
          inListView: true,
        ),
      ],
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: _isLoadingMore
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildAnnouncementCard(PortalAnnouncement announcement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(announcement),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分类和日期
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        announcement.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      announcement.formattedDate,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 标题
                Text(
                  announcement.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // 部门和浏览量
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        announcement.department,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${announcement.viewCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(PortalAnnouncement announcement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PortalAnnouncementDetailPage(announcement: announcement),
      ),
    );
  }
}
