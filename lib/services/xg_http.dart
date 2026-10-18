import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/api_urls.dart';
import '../utils/security_utils.dart';
import 'campus_access_service.dart';
import 'log_service.dart';
import '../models/xg_module_session_snapshot.dart';
import 'session_store.dart';
import 'sso_service.dart';
import 'token_refresh_service.dart';
import 'xg_session_coordinator.dart';

class XgHttp {
  static final XgHttp instance = XgHttp._internal();
  XgHttp._internal();

  Dio? _dio;
  late PersistCookieJar _cookieJar;
  bool _initialized = false;

  Dio get client {
    if (!_initialized) {
      throw Exception('XgHttp 未初始化，请先调用 init()');
    }
    return _dio!;
  }

  CookieJar get cookieJar => _cookieJar;

  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${appDocDir.path}/.cookies/xg_global'),
    );

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiUrls.xgBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (status) => true,
      ),
    );

    SecurityUtils.configureDioSecurity(_dio!);
    _dio!.interceptors.add(CookieManager(_cookieJar));
    _dio!.interceptors.add(XgAuthInterceptor(_cookieJar, _dio!));

    _initialized = true;
  }

  Future<void> clearCookies() async {
    if (!_initialized) {
      return;
    }
    await _cookieJar.deleteAll();
  }

  Future<void> resetSessionArtifacts({String source = 'manual'}) async {
    if (!_initialized) {
      await init();
    }
    await _cookieJar.deleteAll();
    await XgSessionCoordinator.instance.clearCurrentUserModules();
    await SessionStore().clearLegacyXgSessionArtifacts();
    await LogService().log('智慧学工', '已清理旧智慧学工会话: $source');
  }
}

extension XgHttpModuleExtension on XgHttp {
  Map<String, dynamic> _buildModuleExtra(
    XgModule module, {
    String roleId = XgSessionHelper.studentRoleId,
    bool skipSessionRefresh = false,
  }) {
    return {
      'appName': module.appName,
      'appId': module.appId,
      'roleId': roleId,
      'skipSessionRefresh': skipSessionRefresh,
    };
  }

  Future<Response<T>> postFormWithModule<T>(
    String path, {
    required XgModule module,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    String roleId = XgSessionHelper.studentRoleId,
    bool skipSessionRefresh = false,
  }) {
    return client.post<T>(
      path,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: headers,
        extra: _buildModuleExtra(
          module,
          roleId: roleId,
          skipSessionRefresh: skipSessionRefresh,
        ),
      ),
    );
  }

  Future<Response<T>> getWithModule<T>(
    String path, {
    required XgModule module,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String roleId = XgSessionHelper.studentRoleId,
    bool skipSessionRefresh = false,
  }) {
    return client.get<T>(
      path,
      queryParameters: queryParameters,
      options: Options(
        headers: headers,
        extra: _buildModuleExtra(
          module,
          roleId: roleId,
          skipSessionRefresh: skipSessionRefresh,
        ),
      ),
    );
  }
}

class XgAuthInterceptor extends Interceptor {
  final CookieJar _cookieJar;
  final Dio _dio;

  final Map<String, Future<void>> _refreshTasks = <String, Future<void>>{};
  int _campusFailureBurst = 0;
  DateTime? _lastCampusFailureAt;

  XgAuthInterceptor(this._cookieJar, this._dio);

  bool _shouldTripCampusFailureFuse() {
    final lastFailure = _lastCampusFailureAt;
    final now = DateTime.now();
    if (lastFailure == null ||
        now.difference(lastFailure) > const Duration(seconds: 20)) {
      _campusFailureBurst = 0;
    }
    _lastCampusFailureAt = now;
    _campusFailureBurst += 1;
    return _campusFailureBurst >= 2;
  }

  void _resetCampusFailureFuse() {
    _campusFailureBurst = 0;
    _lastCampusFailureAt = null;
  }

  Future<String?> _tryRefreshSchoolAccessToken({
    required XgModule module,
    required Object cause,
  }) async {
    final stopwatch = Stopwatch()..start();
    await LogService().logXgTrace(
      XgTraceLogEntry(
        phase: 'token_refresh',
        event: 'school_token_recovery_started',
        module: module.appName,
        requestKey: 'school_token_recovery',
        result: 'started',
        extra: <String, dynamic>{'cause': cause.toString()},
      ),
    );
    await LogService().log(
      'XgHttp',
      '检测到学校统一认证可能失效，准备静默重登后重建学生态主会话: app=${module.appName} cause=$cause',
    );

    final refreshResult = await TokenRefreshService().tryRefreshToken();
    if (!refreshResult.isRefreshed) {
      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'token_refresh',
          event: 'school_token_recovery_failed',
          module: module.appName,
          requestKey: 'school_token_recovery',
          elapsedMs: stopwatch.elapsedMilliseconds,
          result: 'error',
          reason: refreshResult.status.name,
          extra: <String, dynamic>{'message': refreshResult.message},
        ),
      );
      await LogService().log(
        'XgHttp',
        '学校统一认证静默重登失败: app=${module.appName} status=${refreshResult.status.name} message=${refreshResult.message ?? "null"}',
      );
      return null;
    }

    final refreshedToken = await SessionStore().getAccessToken();
    if (refreshedToken == null || refreshedToken.isEmpty) {
      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'token_refresh',
          event: 'school_token_recovery_failed',
          module: module.appName,
          requestKey: 'school_token_recovery',
          elapsedMs: stopwatch.elapsedMilliseconds,
          result: 'error',
          reason: 'missing_refreshed_token',
        ),
      );
      await LogService().log(
        'XgHttp',
        '学校统一认证静默重登成功，但本地未读到新的 accessToken: app=${module.appName}',
      );
      return null;
    }

    await LogService().logXgTrace(
      XgTraceLogEntry(
        phase: 'token_refresh',
        event: 'school_token_recovery_finished',
        module: module.appName,
        requestKey: 'school_token_recovery',
        elapsedMs: stopwatch.elapsedMilliseconds,
        result: 'ok',
      ),
    );
    await LogService().log(
      'XgHttp',
      '学校统一认证静默重登成功，准备重建学生态主会话: ${module.appName}',
    );
    return refreshedToken;
  }

  Future<void> _prepareStudentModule(
    XgModule module, {
    required String source,
  }) async {
    await XgSessionCoordinator.instance.prepareStudentModule(
      module,
      forceRefresh: true,
      source: source,
    );
  }

  Future<void> _refreshModuleSessionSingleFlight({
    required XgModule module,
    required String requestKey,
  }) async {
    final taskKey = module.appName;
    final existingTask = _refreshTasks[taskKey];
    if (existingTask != null) {
      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'http_recover',
          event: 'session_refresh_reused',
          module: module.appName,
          requestKey: requestKey,
          result: 'reused',
        ),
      );
      await existingTask;
      return;
    }

    final refreshTask = () async {
      try {
        await _prepareStudentModule(module, source: 'http_recover:module');
        _resetCampusFailureFuse();
      } finally {
        _refreshTasks.remove(taskKey);
      }
    }();

    _refreshTasks[taskKey] = refreshTask;
    await refreshTask;
  }

  Future<void> _refreshBaseSession(XgModule module) async {
    await XgSessionHelper.invalidateBaseSession(_cookieJar);
    await _prepareStudentModule(module, source: 'http_recover:base');
  }

  Future<void> _refreshAfterSchoolToken({
    required XgModule module,
    required Object cause,
  }) async {
    final refreshedToken = await _tryRefreshSchoolAccessToken(
      module: module,
      cause: cause,
    );
    if (refreshedToken == null || refreshedToken.isEmpty) {
      throw XgSessionException(
        kind: XgSessionFailureKind.schoolTokenExpired,
        message: '学校统一认证静默重登失败',
        cause: cause,
      );
    }
    await XgSessionHelper.invalidateBaseSession(_cookieJar);
    await _prepareStudentModule(module, source: 'http_recover:school_token');
  }

  Future<Response?> _retryRequestIfRecovered(RequestOptions options) async {
    final response = await _retryRequest(options);
    if (SsoService.isSessionInvalidResponse(response)) {
      return null;
    }
    return response;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipSessionRefresh'] == true) {
      handler.next(options);
      return;
    }
    final appName =
        options.extra['appName'] as String? ?? XgModule.evaluation.appName;
    final commonHeaders = SsoService.getCommonHeaders(appName);
    options.headers.addAll(commonHeaders);
    if (!options.headers.containsKey('Referer')) {
      options.headers['Referer'] = commonHeaders['Referer'];
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    if (_shouldRefresh(response)) {
      try {
        response.requestOptions.extra['statusCode'] = response.statusCode;
        final forceRefresh =
            SsoService.isSessionInvalidStatusCode(response.statusCode) ||
            SsoService.isLoginHtmlContent(response.data);
        final newResponse = await _handleSessionExpiration(
          response.requestOptions,
          forceRefresh: forceRefresh,
        );
        return handler.resolve(newResponse);
      } catch (e) {
        return handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            error: 'SessionExpired: $e',
            type: DioExceptionType.badResponse,
            response: response,
          ),
        );
      }
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response != null && _shouldRefresh(err.response!)) {
      try {
        final resp = err.response!;
        err.requestOptions.extra['statusCode'] = resp.statusCode;
        final forceRefresh =
            SsoService.isSessionInvalidStatusCode(resp.statusCode) ||
            SsoService.isLoginHtmlContent(resp.data);
        final newResponse = await _handleSessionExpiration(
          err.requestOptions,
          forceRefresh: forceRefresh,
        );
        return handler.resolve(newResponse);
      } catch (_) {
        return handler.next(err);
      }
    }
    super.onError(err, handler);
  }

  bool _shouldRefresh(Response response) {
    if (response.requestOptions.extra['isAuthRequest'] == true) {
      return false;
    }
    if (response.requestOptions.extra['isRetry'] == true) {
      return false;
    }
    return SsoService.isSessionInvalidResponse(response);
  }

  Future<Response> _handleSessionExpiration(
    RequestOptions options, {
    required bool forceRefresh,
  }) async {
    final module = XgModule(
      options.extra['appName'] as String? ?? XgModule.evaluation.appName,
      options.extra['appId'] as String? ?? XgModule.evaluation.appId,
    );
    final requestKey =
        '${options.method}:${options.path}:${options.extra['appName'] ?? XgModule.evaluation.appName}';
    final stopwatch = Stopwatch()..start();

    await LogService().logXgTrace(
      XgTraceLogEntry(
        phase: 'http_recover',
        event: 'session_expired_detected',
        module: module.appName,
        requestKey: requestKey,
        result: 'detected',
        extra: <String, dynamic>{
          'forceRefresh': forceRefresh,
          'statusCode': options.extra['statusCode'],
        },
      ),
    );

    await LogService().log('XgHttp', '检测到学生态主会话过期 (${module.appName})，准备刷新...');

    try {
      try {
        await _refreshModuleSessionSingleFlight(
          module: module,
          requestKey: requestKey,
        );
        final response = await _retryRequestIfRecovered(options);
        if (response != null) {
          await LogService().logXgTrace(
            XgTraceLogEntry(
              phase: 'http_recover',
              event: 'session_retry_finished',
              module: module.appName,
              requestKey: requestKey,
              elapsedMs: stopwatch.elapsedMilliseconds,
              result: 'ok',
              extra: <String, dynamic>{
                'statusCode': response.statusCode,
                'recoverStage': 'module',
              },
            ),
          );
          return response;
        }
      } catch (e) {
        if (e is XgSessionException &&
            (e.kind == XgSessionFailureKind.timeout ||
                e.kind == XgSessionFailureKind.network)) {
          rethrow;
        }
      }

      await LogService().log(
        'XgHttp',
        '模块学生态主会话重建后仍失效，升级为首页基础会话重建: ${module.appName}',
      );
      Object? baseStageCause;
      try {
        await _refreshBaseSession(module);
        final response = await _retryRequestIfRecovered(options);
        if (response != null) {
          await LogService().logXgTrace(
            XgTraceLogEntry(
              phase: 'http_recover',
              event: 'session_retry_finished',
              module: module.appName,
              requestKey: requestKey,
              elapsedMs: stopwatch.elapsedMilliseconds,
              result: 'ok',
              extra: <String, dynamic>{
                'statusCode': response.statusCode,
                'recoverStage': 'base',
              },
            ),
          );
          return response;
        }
        baseStageCause = 'base_recover_retry_invalid';
      } catch (e) {
        baseStageCause = e;
        if (e is XgSessionException &&
            (e.kind == XgSessionFailureKind.timeout ||
                e.kind == XgSessionFailureKind.network)) {
          rethrow;
        }
      }

      await LogService().log(
        'XgHttp',
        '首页基础会话重建后仍失效，升级为学校统一认证静默重登: ${module.appName}',
      );
      await _refreshAfterSchoolToken(module: module, cause: baseStageCause);
      final response = await _retryRequestIfRecovered(options);
      if (response != null) {
        await LogService().logXgTrace(
          XgTraceLogEntry(
            phase: 'http_recover',
            event: 'session_retry_finished',
            module: module.appName,
            requestKey: requestKey,
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: 'ok',
            extra: <String, dynamic>{
              'statusCode': response.statusCode,
              'recoverStage': 'school_token',
            },
          ),
        );
        return response;
      }

      throw const XgSessionException(
        kind: XgSessionFailureKind.baseExpired,
        message: '学生态主会话三段恢复后仍未恢复成功',
      );
    } catch (e) {
      final username = await SessionStore().getUsername();
      final isCampusFailure = e is XgSessionException
          ? e.kind == XgSessionFailureKind.timeout ||
                e.kind == XgSessionFailureKind.network
          : CampusAccessService.isCampusNetworkUnavailableError(e);
      if (e is XgSessionException &&
          (e.kind == XgSessionFailureKind.timeout ||
              e.kind == XgSessionFailureKind.network) &&
          username != null &&
          username.isNotEmpty) {
        await XgSessionCoordinator.instance.markModuleStale(
          module,
          XgSessionStaleReason.timeout,
          username: username,
        );
      }
      await LogService().log('XgHttp', '学生态主会话刷新失败(${module.appName}): $e');
      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'http_recover',
          event: 'session_refresh_failed',
          module: module.appName,
          requestKey: requestKey,
          elapsedMs: stopwatch.elapsedMilliseconds,
          result: 'error',
          reason: e.runtimeType.toString(),
          extra: <String, dynamic>{'message': e.toString()},
        ),
      );
      if (isCampusFailure && _shouldTripCampusFailureFuse()) {
        await LogService().log(
          '智慧学工',
          '学生态主会话连续网络失败，触发校园网能力熔断: app=${module.appName} error=$e',
        );
        throw CampusServiceUnavailableException('智慧学工', cause: e);
      }
      rethrow;
    }
  }

  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    final extra = Map<String, dynamic>.from(requestOptions.extra);
    extra['isRetry'] = true;

    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
      extra: extra,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      validateStatus: requestOptions.validateStatus,
      followRedirects: requestOptions.followRedirects,
    );

    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}
