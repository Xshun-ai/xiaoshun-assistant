import 'dart:async';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../constants/api_urls.dart';
import 'sso/sso_error_mapper.dart';
import 'sso/sso_flow.dart';
import 'sso/sso_models.dart';
import 'sso/sso_request_adapter.dart';
import 'sso/xg_session_helper.dart';
import '../utils/security_utils.dart';
import 'campus_access_service.dart';
import 'log_service.dart';
import 'session_store.dart';

export 'sso/sso_error_mapper.dart';
export 'sso/sso_flow.dart';
export 'sso/xg_session_helper.dart';
export 'sso/sso_models.dart';

/// SSO服务（负责跟随303/302等重定向并落地到教务系统）
class SsoService {
  static final Map<String, Future<String>> _mobileTokenTasks =
      <String, Future<String>>{};

  /// 网络客户端（手动处理重定向）
  final Dio _dio;

  /// Cookie存储器
  final CookieJar _jar;

  SsoService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              followRedirects: false,
              // 允许 <400 的状态码通过（不抛异常），方便手动读取 Location 头
              validateStatus: (code) => code != null && code < 400,
            ),
          ),
      _jar = CookieJar() {
    // 统一 HTTPS 证书校验配置。
    if (dio == null) {
      SecurityUtils.configureDioSecurity(_dio);
    }
    _dio.interceptors.add(CookieManager(_jar));
  }

  /// 获取全局 CookieJar 实例
  static Future<PersistCookieJar> getGlobalJar() =>
      SsoFlowSupport.getGlobalJar();

  /// 获取智慧学工通用请求头（包含统一 `User-Agent` 与模块 `Referer`）
  /// [appName] 模块名，例如 `zhcptybbapp`
  static Map<String, String> getCommonHeaders(String appName) =>
      SsoFlowSupport.getCommonHeaders(appName);

  static bool isLikelyAccountSelectionPage(String body) {
    return SsoFlowSupport.isLikelyAccountSelectionPage(body);
  }

  static String? extractAccountSelectionUrlForUsername(
    String body, {
    required String username,
  }) => SsoFlowSupport.extractAccountSelectionUrlForUsername(
    body,
    username: username,
  );

  static String? extractJsRedirectUrl(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'''window\.location\.href\s*=\s*['"]([^'"]+)['"]''',
        caseSensitive: false,
      ),
      RegExp(
        r'''location\.href\s*=\s*['"]([^'"]+)['"]''',
        caseSensitive: false,
      ),
      RegExp(
        r'''window\.location\s*=\s*['"]([^'"]+)['"]''',
        caseSensitive: false,
      ),
      RegExp(r'''location\s*=\s*['"]([^'"]+)['"]''', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? extractMobileTokenFromUrl(String? url) {
    return SsoRequestAdapter.extractMobileTokenFromUrl(url);
  }

  static bool isValidMobileToken(String? token) =>
      SsoFlowSupport.isValidMobileToken(token);

  static bool isCorruptedMobileTokenError(Object error) =>
      SsoFlowSupport.isCorruptedMobileTokenError(error);

  /// 教务上游在 token/会话失效时并不总是返回 401/403，部分接口会直接抛 500。
  /// 这里统一把这些错误视为“需要重新获取移动端 token”的信号。
  static bool shouldRefreshMobileTokenForError(Object error) =>
      SsoFlowSupport.shouldRefreshMobileTokenForError(error);

  static Future<SsoFlowResult> followSsoNavigation({
    required Dio dio,
    required String startUrl,
    required String username,
    Options? options,
    int maxRedirects = 20,
    Duration requestTimeout = SsoRequestAdapter.navigationRequestTimeout,
    Duration flowTimeout = SsoRequestAdapter.navigationFlowTimeout,
  }) async {
    return SsoRequestAdapter.followSsoNavigation(
      dio: dio,
      startUrl: startUrl,
      username: username,
      extractAccountSelectionUrlForUsername:
          extractAccountSelectionUrlForUsername,
      options: options,
      maxRedirects: maxRedirects,
      requestTimeout: requestTimeout,
      flowTimeout: flowTimeout,
    );
  }

  static bool isSessionInvalidStatusCode(int? statusCode) {
    return SsoRequestAdapter.isSessionInvalidStatusCode(statusCode);
  }

  static bool isLoginHtmlContent(dynamic data) {
    return SsoRequestAdapter.isLoginHtmlContent(data);
  }

  static bool isSessionInvalidResponse(Response response) {
    return SsoRequestAdapter.isSessionInvalidResponse(response);
  }

  /// 运行SSO流程，将统一认证的 `IDP_SEC_TOKEN` 注入并跟随重定向直到落地教务系统
  ///
  /// [accessToken] 统一认证的访问令牌（将作为 `IDP_SEC_TOKEN` Cookie）
  /// [username] 用户名（某些重定向可能需要用于拼接参数）
  Future<SsoResult> runSso(String accessToken, String username) async {
    // 1. 注入统一认证令牌到 CookieJar（作用域为统一认证域名）
    final cookie = Cookie('IDP_SEC_TOKEN', accessToken)
      ..httpOnly = true
      ..secure = true
      ..path = '/';

    await _jar.saveFromResponse(Uri.parse(ApiUrls.ssoBaseUrl), [cookie]);
    // 根据抓包记录，jw.sdpt.edu.cn 也携带了该 Cookie，显式设置以确保一致性
    await _jar.saveFromResponse(Uri.parse(ApiUrls.jwWebUrl), [cookie]);

    // 2. 起始SSO跳转地址（根据接口文档）
    final goPath =
        '/api/bff/v1.2/enduser/portal/sso/go_a016aadf8254df286e831b5bd529dcacSFLtserftCW';
    final startUrl = '${ApiUrls.ssoBaseUrl}$goPath';
    await LogService().log('统一认证', 'SSO开始，起始URL: $startUrl');

    // 3. 手动跟随重定向（最多 10 次）
    final flowResult = await followSsoNavigation(
      dio: _dio,
      startUrl: startUrl,
      username: username,
      maxRedirects: 20,
      options: Options(
        headers: {
          'Referer': ApiUrls.ssoEndUserReferer,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
          'Upgrade-Insecure-Requests': '1',
        },
      ),
    );
    final finalResp = flowResult.response;

    await LogService().log(
      '统一认证',
      'SSO结束，状态码: ${finalResp.statusCode}，最终URL: ${LogService().sanitizeSensitiveUrl(finalResp.realUri.toString())}',
    );

    // 4. 读取教务系统域下的 Cookie
    // 注意：必须使用包含 /jsxsd/ 的路径，因为 bzb_jsxsd 的 Path=/jsxsd
    // 如果只用 https://jw.sdpt.edu.cn，只能获取到 Path=/ 的 SERVERID_jsxsd
    final jwUri = finalResp.realUri;
    final cookies = await _jar.loadForRequest(jwUri);

    await LogService().log(
      '统一认证',
      '在 ${LogService().sanitizeSensitiveUrl(jwUri.toString())} 下找到 ${cookies.length} 个Cookie',
    );

    String? bzbJsxsd;
    String? serverIdJsxsd;
    for (final c in cookies) {
      if (c.name == 'bzb_jsxsd') bzbJsxsd = c.value;
      if (c.name == 'SERVERID_jsxsd') serverIdJsxsd = c.value;
    }

    if (bzbJsxsd == null || serverIdJsxsd == null) {
      await LogService().log('统一认证', '未获取到教务系统Cookie，SSO可能未完全落地');
    } else {
      await LogService().log('统一认证', '已获取教务系统Cookie');
    }

    return SsoResult(bzbJsxsd: bzbJsxsd, serverIdJsxsd: serverIdJsxsd);
  }

  /// 运行移动端教务系统SSO流程
  ///
  /// [accessToken] 统一认证的访问令牌
  Future<MobileSsoResult> runMobileSso(
    String accessToken, {
    required String username,
  }) async {
    // 1. 注入统一认证令牌到 CookieJar
    final cookie = Cookie('IDP_SEC_TOKEN', accessToken)
      ..httpOnly = true
      ..secure = true
      ..path = '/';

    await _jar.saveFromResponse(Uri.parse(ApiUrls.ssoBaseUrl), [cookie]);

    // 2. 移动端起始SSO跳转地址
    final goPath =
        '/api/bff/v1.2/enduser/portal/sso/go_df4e7e05bccae052bb7ec7f2257d0df4qr4MgoQoIj7';
    final startUrl = '${ApiUrls.ssoBaseUrl}$goPath';
    await LogService().log('移动端统一认证', '移动端SSO开始，起始URL: $startUrl');

    // 3. 手动跟随重定向
    final flowResult = await followSsoNavigation(
      dio: _dio,
      startUrl: startUrl,
      username: username,
      maxRedirects: 20,
      options: Options(
        headers: {
          'Referer': ApiUrls.ssoEndUserReferer,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
          'Upgrade-Insecure-Requests': '1',
        },
      ),
    );
    final finalResp = flowResult.response;

    await LogService().log('移动端统一认证', '移动端SSO结束，状态码: ${finalResp.statusCode}');

    final token = extractMobileTokenFromUrl(flowResult.finalUrl);
    if (isValidMobileToken(token)) {
      await LogService().log('移动端统一认证', '成功获取移动端Token');
      return MobileSsoResult(token: token);
    }

    await LogService().log(
      '移动端统一认证',
      '未能解析出有效移动端Token，最终URL: ${LogService().sanitizeSensitiveUrl(flowResult.finalUrl)}',
    );
    return MobileSsoResult();
  }

  Future<String> ensureValidMobileToken({
    required SessionStore store,
    required String accessToken,
    required String username,
    bool forceRefresh = false,
  }) {
    final ongoing = _mobileTokenTasks[username];
    if (ongoing != null) {
      return ongoing;
    }

    final task = _ensureValidMobileTokenInternal(
      store: store,
      accessToken: accessToken,
      username: username,
      forceRefresh: forceRefresh,
    );
    _mobileTokenTasks[username] = task;
    unawaited(
      task.then<void>(
        (_) => _clearMobileTokenTask(username, task),
        onError: (Object error, StackTrace stackTrace) {
          _clearMobileTokenTask(username, task);
        },
      ),
    );
    return task;
  }

  void _clearMobileTokenTask(String username, Future<String> task) {
    if (identical(_mobileTokenTasks[username], task)) {
      _mobileTokenTasks.remove(username);
    }
  }

  Future<String> _ensureValidMobileTokenInternal({
    required SessionStore store,
    required String accessToken,
    required String username,
    required bool forceRefresh,
  }) async {
    final cachedToken = forceRefresh ? null : await store.getYdjwToken();
    if (isValidMobileToken(cachedToken)) {
      return cachedToken!;
    }

    if (cachedToken != null && cachedToken.isNotEmpty) {
      await store.clearYdjwToken();
      await LogService().log('移动端统一认证', '检测到缓存移动端Token无效，已清除并重新执行SSO');
    }

    final result = await runMobileSso(accessToken, username: username);
    if (!result.success || !isValidMobileToken(result.token)) {
      throw Exception('获取移动端Token失败');
    }

    await store.saveYdjwToken(result.token!);
    return result.token!;
  }

  /// 运行智慧学工基础 SSO，仅建立首页基础会话。
  Future<XgBaseSessionResult> runXgSsoBaseOnly(
    String accessToken, {
    required String username,
  }) async {
    try {
      final cookie = Cookie('IDP_SEC_TOKEN', accessToken)
        ..httpOnly = true
        ..secure = true
        ..path = '/';
      await _jar.saveFromResponse(Uri.parse(ApiUrls.ssoBaseUrl), [cookie]);
      await _jar.saveFromResponse(Uri.parse(ApiUrls.xgBaseUrl), [cookie]);

      final goPath =
          '/api/bff/v1.2/enduser/portal/sso/go_32eb7c9771ad07baff3cbde52caf7b5axZv5Zwl8VAg';
      final startUrl = '${ApiUrls.ssoBaseUrl}$goPath';
      await LogService().log(
        '智慧学工',
        '基础SSO开始，起始URL: ${LogService().sanitizeSensitiveUrl(startUrl)}',
      );

      final flowResult = await followSsoNavigation(
        dio: _dio,
        startUrl: startUrl,
        username: username,
        maxRedirects: 20,
        options: Options(
          headers: {
            'Referer': ApiUrls.ssoEndUserReferer,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
            'Upgrade-Insecure-Requests': '1',
          },
        ),
        requestTimeout: SsoRequestAdapter.xgNavigationRequestTimeout,
        flowTimeout: SsoRequestAdapter.xgNavigationFlowTimeout,
      );
      final finalResp = flowResult.response;
      await LogService().log(
        '智慧学工',
        '基础SSO结束，URL: ${LogService().sanitizeSensitiveUrl(finalResp.realUri.toString())}',
      );
      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'sso',
          event: 'xg_base_sso_finished',
          module: 'xg_base',
          requestKey: 'xg_base_sso',
          result: 'ok',
          extra: <String, dynamic>{
            'finalUrl': LogService().summarizeTraceUrl(
              finalResp.realUri.toString(),
            ),
          },
        ),
      );

      final xgUri = Uri.parse(
        '${ApiUrls.xgBaseUrl}/xsfw/sys/xggzptapp/index.do',
      );
      final cookies = await _jar.loadForRequest(xgUri);

      String? weu;
      String? jsessionid;
      String? route;
      for (final c in cookies) {
        if (c.name == '_WEU') weu = c.value;
        if (c.name == 'JSESSIONID') jsessionid = c.value;
        if (c.name == 'route') route = c.value;
      }

      await LogService().log(
        '智慧学工',
        '基础会话Cookie就绪: WEU=${weu != null}, JSESSIONID=${jsessionid != null}, route=${route != null}',
      );
      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'sso',
          event: 'xg_base_cookie_ready',
          module: 'xg_base',
          requestKey: 'xg_base_sso',
          result: weu != null ? 'ok' : 'error',
          extra: <String, dynamic>{
            'hasWeu': weu != null,
            'hasJsessionId': jsessionid != null,
            'hasRoute': route != null,
          },
        ),
      );

      try {
        final jar = await getGlobalJar();
        await XgSessionHelper.injectBaseCookies(
          jar,
          weu: weu,
          jsessionid: jsessionid,
          route: route,
        );
      } catch (_) {}

      return XgBaseSessionResult(
        weu: weu,
        jsessionid: jsessionid,
        route: route,
      );
    } on XgSessionException {
      rethrow;
    } on TimeoutException catch (e) {
      throw XgSessionException(
        kind: XgSessionFailureKind.timeout,
        message: '智慧学工基础SSO超时',
        cause: e,
      );
    } on DioException catch (e) {
      throw XgSessionHelper.mapToSessionException(
        e,
        fallbackKind: XgSessionFailureKind.baseExpired,
        context: '智慧学工基础SSO失败',
      );
    } catch (e) {
      if (CampusAccessService.isCampusNetworkUnavailableError(e)) {
        throw XgSessionException(
          kind: XgSessionFailureKind.network,
          message: '智慧学工基础SSO网络异常',
          cause: e,
        );
      }
      throw XgSessionException(
        kind: XgSessionFailureKind.unknown,
        message: '智慧学工基础SSO失败',
        cause: e,
      );
    }
  }
}
