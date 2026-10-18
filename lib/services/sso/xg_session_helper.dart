import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../constants/api_urls.dart';
import '../campus_access_service.dart';
import '../log_service.dart';
import '../sso_service.dart' show SsoService;
import 'sso_error_mapper.dart';
import 'sso_models.dart';
import 'xg_session_cookie_helper.dart';

/// 智慧学工统一会话工具
class XgSessionHelper {
  static const String studentRoleId = 'ee7033e0db0642dbb55dc9c2e3869861';

  static XgSessionException mapToSessionException(
    Object error, {
    required XgSessionFailureKind fallbackKind,
    required String context,
  }) {
    return SsoErrorMapper.mapToSessionException(
      error,
      fallbackKind: fallbackKind,
      context: context,
      isSessionInvalidResponse: SsoService.isSessionInvalidResponse,
      isCampusNetworkUnavailableError:
          CampusAccessService.isCampusNetworkUnavailableError,
    );
  }

  /// 检查是否存在有效的 `_WEU` Cookie
  static Future<bool> hasValidWeu(CookieJar jar) async {
    return XgSessionCookieHelper.hasValidWeu(jar);
  }

  static Future<bool> hasValidBaseSession(CookieJar jar) async {
    return XgSessionCookieHelper.hasValidBaseSession(jar);
  }

  static Future<void> injectBaseCookies(
    CookieJar jar, {
    String? weu,
    String? jsessionid,
    String? route,
  }) async {
    await XgSessionCookieHelper.injectBaseCookies(
      jar,
      weu: weu,
      jsessionid: jsessionid,
      route: route,
    );
  }

  static Future<void> injectCookies(
    CookieJar jar, {
    required String weu,
    String? jsessionid,
    String? route,
    required String appName,
  }) async {
    await XgSessionCookieHelper.injectCookies(
      jar,
      weu: weu,
      jsessionid: jsessionid,
      route: route,
      appName: appName,
    );
  }

  static Future<T> runSerialized<T>(Future<T> Function() action) async {
    return XgSessionCookieHelper.runSerialized(action);
  }

  static Future<Response<T>> _runAuthRequest<T>(
    Future<Response<T>> Function() request, {
    required XgSessionFailureKind failureKind,
    required String context,
  }) async {
    return SsoErrorMapper.runAuthRequest(
      request,
      failureKind: failureKind,
      context: context,
      isSessionInvalidResponse: SsoService.isSessionInvalidResponse,
      isCampusNetworkUnavailableError:
          CampusAccessService.isCampusNetworkUnavailableError,
    );
  }

  static Future<void> _ensureBaseSessionUnlocked({
    required CookieJar jar,
    required String accessToken,
    required String username,
    SsoService? ssoService,
  }) async {
    if (await hasValidBaseSession(jar)) {
      return;
    }

    final sso = ssoService ?? SsoService();
    final res = await sso.runXgSsoBaseOnly(accessToken, username: username);
    if (!res.success || res.weu == null || res.weu!.isEmpty) {
      throw const XgSessionException(
        kind: XgSessionFailureKind.baseExpired,
        message: '未获取到有效的智慧学工首页基础会话',
      );
    }

    await injectBaseCookies(
      jar,
      weu: res.weu,
      jsessionid: res.jsessionid,
      route: res.route,
    );

    if (!await hasValidBaseSession(jar)) {
      throw const XgSessionException(
        kind: XgSessionFailureKind.baseExpired,
        message: '智慧学工首页基础会话写入失败',
      );
    }
  }

  static Future<void> ensureBaseSession({
    required CookieJar jar,
    required String accessToken,
    required String username,
    SsoService? ssoService,
    bool forceRefresh = false,
  }) async {
    await runSerialized(() async {
      if (forceRefresh) {
        await invalidateBaseSession(jar);
      }

      await _ensureBaseSessionUnlocked(
        jar: jar,
        accessToken: accessToken,
        username: username,
        ssoService: ssoService,
      );
    });
  }

  static Future<void> _ensureStudentSessionUnlocked({
    required Dio dio,
    required CookieJar jar,
    required String accessToken,
    required String username,
    required XgModule module,
    SsoService? ssoService,
    bool doWarmUp = true,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidateBaseSession(jar);
      await invalidateSession(jar, module: module);
      await LogService().log(
        '智慧学工',
        '强制刷新学生态模块会话（包含基础会话）: ${module.appName}',
      );
    }

    await _ensureBaseSessionUnlocked(
      jar: jar,
      accessToken: accessToken,
      username: username,
      ssoService: ssoService,
    );

    await _fetchModuleConfig(dio, module);
    await _selectRole(dio, module: module, roleId: studentRoleId);
    if (doWarmUp) {
      await warmUp(dio, module: module, roleId: studentRoleId);
    }
  }

  static Future<void> _rebuildBaseSessionAndRetryModule({
    required Dio dio,
    required CookieJar jar,
    required String accessToken,
    required String username,
    required XgModule module,
    SsoService? ssoService,
    required bool doWarmUp,
  }) async {
    await LogService().log(
      '智慧学工',
      '检测到首页基础会话失效，准备清理基础会话并重建后重试模块会话: ${module.appName}',
    );
    await invalidateBaseSession(jar);
    await _ensureBaseSessionUnlocked(
      jar: jar,
      accessToken: accessToken,
      username: username,
      ssoService: ssoService,
    );
    await _fetchModuleConfig(dio, module);
    await _selectRole(dio, module: module, roleId: studentRoleId);
    if (doWarmUp) {
      await warmUp(dio, module: module, roleId: studentRoleId);
    }
  }

  static Map<String, dynamic> _buildAuthExtra({
    required XgModule module,
    required String roleId,
  }) {
    return {
      'isAuthRequest': true,
      'appName': module.appName,
      'appId': module.appId,
      'roleId': roleId,
      'skipSessionRefresh': true,
    };
  }

  static Future<void> _fetchModuleConfig(Dio dio, XgModule module) async {
    await _runAuthRequest(
      () => dio.get(
        '${ApiUrls.xgBaseUrl}/xsfw/sys/swpubapp/indexmenu/getAppConfig.do',
        queryParameters: {'appId': module.appId, 'appName': module.appName},
        options: Options(
          validateStatus: (_) => true,
          headers: SsoService.getCommonHeaders(module.appName),
          extra: _buildAuthExtra(module: module, roleId: studentRoleId),
        ),
      ),
      failureKind: XgSessionFailureKind.baseExpired,
      context: '模块配置获取失败(${module.appName})',
    );
  }

  static Future<void> _selectRole(
    Dio dio, {
    required XgModule module,
    required String roleId,
  }) async {
    await _runAuthRequest(
      () => dio.post(
        '${ApiUrls.xgBaseUrl}/xsfw/sys/funauthapp/selectRole.do',
        data: {'ROLEID': roleId, 'APPNAME': module.appName},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: SsoService.getCommonHeaders(module.appName),
          validateStatus: (_) => true,
          extra: _buildAuthExtra(module: module, roleId: roleId),
        ),
      ),
      failureKind: XgSessionFailureKind.baseExpired,
      context: '角色切换失败(${module.appName}, role=$roleId)',
    );
  }

  /// 模块唤醒（建立模块级会话）
  static Future<void> warmUp(
    Dio dio, {
    required XgModule module,
    String roleId = studentRoleId,
  }) async {
    await _runAuthRequest(
      () => dio.get(
        '${ApiUrls.xgBaseUrl}/xsfw/sys/${module.appName}/*default/index.do?THEME=purple',
        options: Options(
          followRedirects: true,
          validateStatus: (_) => true,
          headers: SsoService.getCommonHeaders(module.appName),
          extra: _buildAuthExtra(module: module, roleId: roleId),
        ),
      ),
      failureKind: XgSessionFailureKind.baseExpired,
      context: '模块唤醒失败(${module.appName}, role=$roleId)',
    );
  }

  /// 清除指定域名的所有Cookie
  static Future<void> clearCookies(CookieJar jar) async {
    await XgSessionCookieHelper.clearCookies(jar);
  }

  static Future<void> invalidateSession(
    CookieJar jar, {
    XgModule? module,
  }) async {
    await XgSessionCookieHelper.invalidateSession(jar, module: module);
  }

  static Future<void> invalidateBaseSession(CookieJar jar) async {
    await XgSessionCookieHelper.invalidateBaseSession(jar);
  }

  static Future<void> invalidateModuleSession(
    CookieJar jar, {
    required XgModule module,
  }) async {
    await XgSessionCookieHelper.invalidateModuleSession(jar, module: module);
  }

  static Future<void> invalidateAllXgSessions(CookieJar jar) async {
    await XgSessionCookieHelper.invalidateAllXgSessions(jar);
  }

  static Future<void> ensureStudentSession({
    required Dio dio,
    required CookieJar jar,
    required String accessToken,
    required String username,
    required XgModule module,
    SsoService? ssoService,
    bool doWarmUp = true,
    bool forceRefresh = false,
  }) async {
    await runSerialized(() async {
      try {
        await _ensureStudentSessionUnlocked(
          dio: dio,
          jar: jar,
          accessToken: accessToken,
          username: username,
          module: module,
          ssoService: ssoService,
          doWarmUp: doWarmUp,
          forceRefresh: forceRefresh,
        );
      } on XgSessionException catch (e) {
        if (e.kind != XgSessionFailureKind.baseExpired) {
          rethrow;
        }
        await _rebuildBaseSessionAndRetryModule(
          dio: dio,
          jar: jar,
          accessToken: accessToken,
          username: username,
          module: module,
          ssoService: ssoService,
          doWarmUp: doWarmUp,
        );
      }
    });
  }

}
