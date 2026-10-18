import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/portal_announcement.dart';
import 'auth_service.dart';
import 'home_data_portal_loader.dart';
import 'home_data_schedule_loader.dart';
import 'log_service.dart';
import 'portal_announcement_service.dart';
import 'schedule_service.dart';
import 'session_store.dart';
import 'sso_service.dart';
import 'token_refresh_service.dart';

/// 首页数据加载服务。
///
/// 当前版本只包含学校直连能力：用户信息、课表和融合门户公告。
class HomeDataService {
  final SessionStore _store = SessionStore();
  final AuthService _auth = AuthService();
  final SsoService _ssoService = SsoService();
  final ScheduleService _scheduleService = ScheduleService();
  final LogService _logger = LogService();
  final TokenRefreshService _tokenRefresh = TokenRefreshService();
  final PortalAnnouncementService _portalService = PortalAnnouncementService();

  HomeDataScheduleLoader get _scheduleLoader => HomeDataScheduleLoader(
    store: _store,
    scheduleService: _scheduleService,
    tokenRefresh: _tokenRefresh,
    logger: _logger,
    ensureValidMobileToken: _ensureValidMobileToken,
    shouldRetryWithTokenRefresh: _shouldRetryWithTokenRefresh,
  );

  HomeDataPortalLoader get _portalLoader => HomeDataPortalLoader(
    store: _store,
    portalService: _portalService,
    tokenRefresh: _tokenRefresh,
    shouldRetryWithTokenRefresh: _shouldRetryWithTokenRefresh,
  );

  bool _shouldRetryWithTokenRefresh(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      return statusCode == 401 || statusCode == 403;
    }

    final message = error.toString();
    return message.contains('401') ||
        message.contains('403') ||
        message.contains('登录状态已失效') ||
        message.contains('访问令牌已过期');
  }

  Future<String> _ensureValidMobileToken({
    required String accessToken,
    bool forceRefresh = false,
  }) async {
    final username = await _store.getUsername();
    if (username == null || username.isEmpty) {
      throw Exception('未获取到当前用户名，无法执行移动端SSO');
    }

    return _ssoService.ensureValidMobileToken(
      store: _store,
      accessToken: accessToken,
      username: username,
      forceRefresh: forceRefresh,
    );
  }

  /// 加载用户显示名称。
  ///
  /// 优先从缓存读取，缓存未命中时从学校统一认证获取。
  Future<String?> loadDisplayName() async {
    String? name = await _store.getDisplayName();

    if (name == null || name.isEmpty) {
      final token = await _store.getAccessToken();
      if (token != null) {
        try {
          final info = await _auth.getUserInfo(token);
          name = info.displayName;

          await _store.saveDisplayName(info.displayName);
          await _store.saveUserInfoDetails(
            college: info.ouName,
            className: info.className,
          );
        } on DioException catch (e) {
          if (e.response?.statusCode == 401) {
            debugPrint('[用户信息] 访问令牌已过期,尝试刷新');
            final refreshed = await _tokenRefresh.tryRefreshToken();
            if (refreshed.isRefreshed) {
              name = await _store.getDisplayName();
            }
          } else {
            debugPrint('[用户信息] 加载失败: $e');
          }
        } catch (e) {
          debugPrint('[用户信息] 加载失败: $e');
        }
      }
    }

    return name;
  }

  /// 加载今日课程数据（缓存优先）。
  Future<List<Map<String, String>>?> loadScheduleCached() {
    return _scheduleLoader.loadScheduleCached();
  }

  /// 加载今日课程数据（网络刷新）。
  Future<List<Map<String, String>>> loadScheduleFresh() {
    return _scheduleLoader.loadScheduleFresh();
  }

  Future<void> warmFullScheduleCache() {
    return _scheduleLoader.warmFullScheduleCache();
  }

  /// 加载融合门户公告（缓存优先）。
  Future<List<PortalAnnouncement>?> loadPortalAnnouncementsCached() {
    return _portalLoader.loadPortalAnnouncementsCached();
  }

  /// 加载融合门户公告（网络刷新）。
  Future<List<PortalAnnouncement>> loadPortalAnnouncementsFresh() {
    return _portalLoader.loadPortalAnnouncementsFresh();
  }
}
