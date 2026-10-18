import 'dart:async';

import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../models/user_info.dart';
import '../../../services/auth_service.dart';
import '../../../services/campus_access_service.dart';
import '../../../services/session_store.dart';
import '../../../ui/components/app_card.dart';
import '../../../ui/components/status_chip.dart';
import '../../../ui/patterns/summary_header_card.dart';
import '../../../ui/states/skeleton_loading.dart';
import '../../settings_page.dart';

/// 我的Tab - 用户个人中心，展示用户信息
class ProfileTab extends StatefulWidget {
  final Future<void> Function()? waitForSessionReady;
  final Future<UserInfo> Function(String accessToken)? userInfoLoader;
  final Future<void> Function()? onLogoutRequested;

  const ProfileTab({
    super.key,
    this.waitForSessionReady,
    this.userInfoLoader,
    this.onLogoutRequested,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with AutomaticKeepAliveClientMixin {
  UserInfo? _userInfo;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUserInfo());
  }

  Future<void> _loadUserInfo() async {
    final store = SessionStore();

    // 尝试优先加载缓存
    if (_userInfo == null) {
      final cachedInfo = await store.getUserInfo();
      if (cachedInfo != null && mounted) {
        setState(() {
          _userInfo = cachedInfo;
        });
      }
    }

    if (_userInfo == null) {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    } else if (mounted && _error != null) {
      setState(() {
        _error = null;
      });
    }

    try {
      await widget.waitForSessionReady?.call();

      final token = await store.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('未找到访问令牌，请重新登录');
      }

      final info =
          await (widget.userInfoLoader?.call(token) ??
              AuthService().getUserInfo(token));

      if (mounted) {
        setState(() {
          _userInfo = info;
          _error = null;
        });
        await store.saveUserInfo(info);
        await store.saveDisplayName(info.displayName);
        await store.saveUserInfoDetails(
          college: info.ouName,
          className: info.className,
        );
      }
    } catch (e) {
      if (mounted) {
        if (_userInfo == null) {
          setState(() {
            _error = CampusAccessService.isCampusNetworkUnavailableError(e)
                ? '校园网服务暂不可用，请稍后重试'
                : '请稍后重试';
          });
        } else {
          debugPrint('后台刷新用户信息失败: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileSummaryCard(primaryColor),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    '常用功能',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildFunctionListCard(
                  context,
                  title: '设置',
                  subtitle: '系统设置',
                  icon: Icons.settings_outlined,
                  color: Colors.grey,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSummaryCard(Color primaryColor) {
    if (_userInfo == null && _loading) {
      return AppCard(
        margin: EdgeInsets.zero,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceSoft,
                border: Border.all(color: AppColors.borderLight),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoading(
                    width: 120,
                    height: 24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 10),
                  SkeletonLoading(
                    width: 90,
                    height: 16,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SkeletonLoading(
                        width: 110,
                        height: 28,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      SkeletonLoading(
                        width: 90,
                        height: 28,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SummaryHeaderCard(
      eyebrow: '个人资料',
      title: _userInfo?.displayName ?? '未登录',
      subtitle: '学号 ${_userInfo?.username ?? '--'}',
      leading: _buildAvatar(primaryColor),
      meta: [
        _buildMetaChip(Icons.school_outlined, _userInfo?.ouName ?? '学院信息缺失'),
        _buildMetaChip(Icons.class_outlined, _userInfo?.className ?? '班级信息缺失'),
      ],
      footer: _error == null
          ? null
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '资料更新失败：$_error',
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar(Color primaryColor) {
    final displayName = _userInfo?.displayName ?? '';
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1) : 'S';

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.primarySoftBorder),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return StatusChip(
      icon: icon,
      label: text,
      backgroundColor: AppColors.surfaceSoft,
      foregroundColor: AppColors.textSecondary,
      borderColor: AppColors.borderLight,
    );
  }

  Widget _buildFunctionListCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
    String? trailingText,
    Color? trailingTextColor,
    Key? trailingTextKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      trailingText,
                      key: trailingTextKey,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: trailingTextColor ?? Colors.black87,
                      ),
                    ),
                  ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
