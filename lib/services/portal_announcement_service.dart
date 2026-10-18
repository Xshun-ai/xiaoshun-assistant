import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'dart:convert';
import '../models/portal_announcement.dart';
import '../constants/api_urls.dart';
import '../services/session_store.dart';
import '../services/log_service.dart';
import '../services/sso_service.dart';
import '../services/campus_access_service.dart';

/// 融合门户公告服务
class PortalAnnouncementService {
  static final PortalAnnouncementService _instance =
      PortalAnnouncementService._internal();
  factory PortalAnnouncementService() => _instance;
  PortalAnnouncementService._internal();

  Dio? _dio;
  CookieJar? _cookieJar;
  bool _initialized = false;
  Future<bool>? _sessionTask;

  /// 初始化 HTTP 客户端
  Future<void> init() async {
    if (_initialized) return;

    _cookieJar = CookieJar();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        maxRedirects: 10,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio!.interceptors.add(CookieManager(_cookieJar!));
    _initialized = true;

    await LogService().log('融合门户', '公告服务初始化完成');
  }

  /// 清除会话（退出登录时调用）
  Future<void> clearSession() async {
    if (_initialized && _cookieJar != null) {
      await _cookieJar!.deleteAll();
      _initialized = false;
      _cookieJar = null;
      _dio = null;
      _sessionTask = null;
      await LogService().log('融合门户', '已清除会话和Cookie');
    }
  }

  /// 确保会话（通过SSO登录到融合门户）
  Future<bool> _ensureSession() async {
    final ongoing = _sessionTask;
    if (ongoing != null) {
      return ongoing;
    }

    final future = _doEnsureSession();
    _sessionTask = future;

    try {
      return await future;
    } catch (e) {
      rethrow;
    } finally {
      if (identical(_sessionTask, future)) {
        _sessionTask = null;
      }
    }
  }

  Future<bool> _doEnsureSession() async {
    try {
      await init();

      final store = SessionStore();
      final accessToken = await store.getAccessToken();
      final username = await store.getUsername();
      if (accessToken == null || accessToken.isEmpty) {
        await LogService().log('融合门户', '确保会话失败: accessToken为空');
        return false;
      }
      if (username == null || username.isEmpty) {
        await LogService().log('融合门户', '确保会话失败: username为空');
        return false;
      }

      final eipCookies = await _cookieJar!.loadForRequest(
        Uri.parse(ApiUrls.eipBaseUrl),
      );
      final hasSession = eipCookies.any(
        (c) => c.name == 'JSESSIONID' && c.value.isNotEmpty,
      );
      if (hasSession) {
        await LogService().log('融合门户', '会话已存在，复用');
        return true;
      }

      await LogService().log(
        '融合门户',
        'SSO流程开始: accessToken长度=${accessToken.length}',
      );

      final cookie = Cookie('IDP_SEC_TOKEN', accessToken)
        ..httpOnly = true
        ..secure = true
        ..path = '/';
      await _cookieJar!.saveFromResponse(Uri.parse(ApiUrls.ssoBaseUrl), [
        cookie,
      ]);

      final startUrl =
          '${ApiUrls.ssoBaseUrl}/api/bff/v1.2/enduser/portal/sso/go_e70d03cb3552434a4a1f3ae16aeff539e7IPdq5mDgc';
      await SsoService.followSsoNavigation(
        dio: _dio!,
        startUrl: startUrl,
        username: username,
        options: Options(
          headers: {
            'Referer': ApiUrls.ssoEndUserReferer,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Cookie': 'IDP_SEC_TOKEN=$accessToken',
            'Upgrade-Insecure-Requests': '1',
          },
        ),
      );

      final finalCookies = await _cookieJar!.loadForRequest(
        Uri.parse(ApiUrls.eipBaseUrl),
      );
      await LogService().log(
        '融合门户',
        'Cookie数量: ${finalCookies.length}, 名称: ${finalCookies.map((c) => c.name).join(", ")}',
      );

      final finalSession = finalCookies.any(
        (c) => c.name == 'JSESSIONID' && c.value.isNotEmpty,
      );
      if (finalSession) {
        await LogService().log('融合门户', '成功建立会话');
        return true;
      }

      await LogService().log('融合门户', '确保会话失败: 未获取到JSESSIONID');
      return false;
    } catch (e) {
      await LogService().log('融合门户', '确保会话异常: $e');
      if (CampusAccessService.isCampusNetworkUnavailableError(e)) {
        throw CampusServiceUnavailableException('融合门户公告', cause: e);
      }
      return false;
    }
  }

  /// 获取公告列表（JSON API）
  Future<List<PortalAnnouncement>> fetchAnnouncements({
    int page = 1,
    int pageSize = 30,
  }) async {
    try {
      // 确保会话
      final hasSession = await _ensureSession();
      if (!hasSession) {
        await LogService().log('融合门户', '获取公告列表失败: 未能建立会话');
        throw Exception('未能建立会话');
      }

      // 调用JSON API获取公告列表
      final response = await _dio!.post(
        '${ApiUrls.eipBaseUrl}/EIP/affiche/queryAfficheListForUser.htm',
        data: 'pageIndex=${page - 1}&pageSize=$pageSize',
        options: Options(
          contentType: 'application/x-www-form-urlencoded; Charset=UTF-8',
          followRedirects: false, // 不自动跟随重定向，手动检测302
          validateStatus: (status) => status! < 400, // 302也视为成功，便于检测
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': '*/*',
          },
        ),
      );

      // 检测302重定向，说明会话过期
      if (response.statusCode == 302 || response.statusCode == 301) {
        await LogService().log(
          '融合门户',
          '检测到会话过期(${response.statusCode})，清除Cookie并重试',
        );

        // 清除过期Cookie
        await _cookieJar!.deleteAll();

        // 重新建立会话
        final retrySession = await _ensureSession();
        if (!retrySession) {
          await LogService().log('融合门户', '重新建立会话失败');
          throw Exception('会话过期且重新登录失败');
        }

        // 重试请求
        final retryResponse = await _dio!.post(
          '${ApiUrls.eipBaseUrl}/EIP/affiche/queryAfficheListForUser.htm',
          data: 'pageIndex=${page - 1}&pageSize=$pageSize',
          options: Options(
            contentType: 'application/x-www-form-urlencoded; Charset=UTF-8',
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': '*/*',
            },
          ),
        );

        if (retryResponse.statusCode != 200) {
          await LogService().log(
            '融合门户',
            '重试后仍失败: HTTP ${retryResponse.statusCode}',
          );
          throw Exception('HTTP ${retryResponse.statusCode}');
        }

        return _parseAnnouncementList(retryResponse);
      }

      if (response.statusCode != 200) {
        await LogService().log(
          '融合门户',
          '获取公告列表失败: HTTP ${response.statusCode}',
        );
        throw Exception('HTTP ${response.statusCode}');
      }

      return _parseAnnouncementList(response);
    } catch (e) {
      await LogService().log('融合门户', '获取公告列表异常: $e');
      if (CampusAccessService.isCampusNetworkUnavailableError(e)) {
        throw CampusServiceUnavailableException('融合门户公告', cause: e);
      }
      rethrow;
    }
  }

  /// 解析公告列表响应
  List<PortalAnnouncement> _parseAnnouncementList(Response response) {
    final jsonData = response.data is String
        ? jsonDecode(response.data)
        : response.data;
    final List<dynamic> dataList = jsonData['data'] ?? [];

    final announcements = <PortalAnnouncement>[];
    for (var item in dataList) {
      try {
        final id = item['id'] ?? '';
        final title = item['title'] ?? '';
        final department = item['orgname'] ?? '';
        final category = item['tag'] ?? '';

        // 转换时间戳为日期字符串
        final publishTimestamp = item['publishdate'];
        String publishDate = '';
        if (publishTimestamp != null) {
          final dateTime = DateTime.fromMillisecondsSinceEpoch(
            publishTimestamp as int,
          );
          publishDate =
              '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
        }

        final viewCount = item['browsecount'] ?? 0;

        announcements.add(
          PortalAnnouncement(
            id: id,
            category: category,
            title: title,
            department: department,
            publishDate: publishDate,
            viewCount: viewCount,
            detailUrl: '', // JSON API不需要URL，使用ID即可
          ),
        );
      } catch (e) {
        continue;
      }
    }

    return announcements;
  }

  /// 获取公告详情（通过ID从 JSON API）
  /// 支持分页查询，确保能找到较旧的公告
  Future<Map<String, dynamic>?> fetchAnnouncementDetail(
    String announcementId,
  ) async {
    try {
      // 确保会话
      final hasSession = await _ensureSession();
      if (!hasSession) {
        await LogService().log('融合门户', '获取公告详情失败: 未能建立会话');
        return null;
      }

      // 分页查询，每页100条，最多查询10页（共1000条）
      const int pageSize = 100;
      const int maxPages = 10;

      for (int pageIndex = 0; pageIndex < maxPages; pageIndex++) {
        final response = await _dio!.post(
          '${ApiUrls.eipBaseUrl}/EIP/affiche/queryAfficheListForUser.htm',
          data: 'pageIndex=$pageIndex&pageSize=$pageSize',
          options: Options(
            contentType: 'application/x-www-form-urlencoded; Charset=UTF-8',
            followRedirects: false, // 不自动跟随重定向
            validateStatus: (status) => status! < 400, // 302也视为成功
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': '*/*',
            },
          ),
        );

        // 检测会话过期
        if (response.statusCode == 302 || response.statusCode == 301) {
          await LogService().log('融合门户', '获取公告详情时检测到会话过期，重新登录');
          await _cookieJar!.deleteAll();

          final retrySession = await _ensureSession();
          if (!retrySession) {
            await LogService().log('融合门户', '重新建立会话失败');
            return null;
          }

          // 重试当前页
          return await fetchAnnouncementDetail(announcementId);
        }

        if (response.statusCode != 200) {
          await LogService().log(
            '融合门户',
            '获取公告详情失败: HTTP ${response.statusCode}',
          );
          return null;
        }

        final jsonData = response.data is String
            ? jsonDecode(response.data)
            : response.data;
        final List<dynamic> dataList = jsonData['data'] ?? [];

        // 在当前页查找匹配的公告
        for (var item in dataList) {
          if (item['id'] == announcementId) {
            await LogService().log(
              '融合门户',
              '成功获取公告详情(第${pageIndex + 1}页)',
            );
            return item as Map<String, dynamic>;
          }
        }

        // 如果当前页没有数据，说明已经查完所有公告
        if (dataList.isEmpty) {
          break;
        }
      }

      await LogService().log('融合门户', '未找到公告详情: $announcementId');
      return null;
    } catch (e) {
      await LogService().log('融合门户', '获取公告详情异常: $e');
      if (CampusAccessService.isCampusNetworkUnavailableError(e)) {
        throw CampusServiceUnavailableException('融合门户公告', cause: e);
      }
      return null;
    }
  }
}
