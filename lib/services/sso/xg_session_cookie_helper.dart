import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';

import '../../constants/api_urls.dart';
import '../log_service.dart';
import '../session_store.dart';
import '../xg_session_coordinator.dart';
import 'sso_models.dart';

class XgSessionCookieHelper {
  static Future<void> _sessionMutationChain = Future.value();

  static Future<bool> hasValidWeu(CookieJar jar) async {
    final cookies = await jar.loadForRequest(
      Uri.parse('${ApiUrls.xgBaseUrl}/xsfw/sys/xggzptapp/index.do'),
    );
    return cookies.any((c) => c.name == '_WEU' && c.value.isNotEmpty);
  }

  static Future<bool> hasValidBaseSession(CookieJar jar) async {
    return hasValidWeu(jar);
  }

  static Future<void> injectBaseCookies(
    CookieJar jar, {
    String? weu,
    String? jsessionid,
    String? route,
  }) async {
    await jar.delete(Uri.parse(ApiUrls.xgBaseUrl), true);
    await jar.delete(Uri.parse('${ApiUrls.xgBaseUrl}/xsfw/'), true);

    final list = <Cookie>[
      if (weu != null && weu.isNotEmpty)
        Cookie('_WEU', weu)
          ..domain = ApiUrls.xgDomain
          ..path = '/',
      if (jsessionid != null && jsessionid.isNotEmpty)
        Cookie('JSESSIONID', jsessionid)
          ..domain = ApiUrls.xgDomain
          ..path = '/',
      if (route != null && route.isNotEmpty)
        Cookie('route', route)
          ..domain = ApiUrls.xgDomain
          ..path = '/',
    ];
    if (list.isEmpty) {
      return;
    }

    await jar.saveFromResponse(Uri.parse(ApiUrls.xgBaseUrl), list);
    await jar.saveFromResponse(Uri.parse('${ApiUrls.xgBaseUrl}/xsfw/'), list);
  }

  static Future<void> injectCookies(
    CookieJar jar, {
    required String weu,
    String? jsessionid,
    String? route,
    required String appName,
  }) async {
    await injectBaseCookies(
      jar,
      weu: weu,
      jsessionid: jsessionid,
      route: route,
    );

    final list = <Cookie>[
      Cookie('_WEU', weu)
        ..domain = ApiUrls.xgDomain
        ..path = '/',
      if (jsessionid != null && jsessionid.isNotEmpty)
        Cookie('JSESSIONID', jsessionid)
          ..domain = ApiUrls.xgDomain
          ..path = '/',
      if (route != null && route.isNotEmpty)
        Cookie('route', route)
          ..domain = ApiUrls.xgDomain
          ..path = '/',
    ];
    await jar.saveFromResponse(
      Uri.parse('${ApiUrls.xgBaseUrl}/xsfw/sys/$appName/'),
      list,
    );
  }

  static Future<T> runSerialized<T>(Future<T> Function() action) async {
    final previous = _sessionMutationChain;
    final completer = Completer<void>();
    _sessionMutationChain = previous.then((_) => completer.future);
    await previous;
    try {
      return await action();
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  static Future<void> clearCookies(CookieJar jar) async {
    try {
      await jar.deleteAll();
      await SessionStore().clearLegacyXgSessionArtifacts();
      await XgSessionCoordinator.instance.clearCurrentUserModules();
      await LogService().log('智慧学工', '已清除本地Cookie');
    } catch (e) {
      await LogService().log('智慧学工', '清除Cookie失败: $e');
    }
  }

  static Future<void> invalidateSession(
    CookieJar jar, {
    XgModule? module,
  }) async {
    if (module != null) {
      await invalidateModuleSession(jar, module: module);
      return;
    }
    await invalidateAllXgSessions(jar);
  }

  static Future<void> invalidateBaseSession(CookieJar jar) async {
    try {
      await jar.delete(Uri.parse(ApiUrls.xgBaseUrl), true);
      await jar.delete(Uri.parse('${ApiUrls.xgBaseUrl}/xsfw/'), true);
      await XgSessionCoordinator.instance.clearCurrentUserModules();
      await LogService().log('智慧学工', '已清除首页基础会话与模块快照');
    } catch (e) {
      await LogService().log('智慧学工', '清除首页基础会话失败: $e');
    }
  }

  static Future<void> invalidateModuleSession(
    CookieJar jar, {
    required XgModule module,
  }) async {
    try {
      await jar.delete(
        Uri.parse('${ApiUrls.xgBaseUrl}/xsfw/sys/${module.appName}/'),
        true,
      );
      await SessionStore().clearXgModuleSnapshot(module.appName);
      await LogService().log(
        '智慧学工',
        '已清除模块会话: ${module.appName}',
      );
    } catch (e) {
      await LogService().log(
        '智慧学工',
        '清除模块会话失败(${module.appName}): $e',
      );
    }
  }

  static Future<void> invalidateAllXgSessions(CookieJar jar) async {
    await invalidateBaseSession(jar);
    await SessionStore().clearLegacyXgSessionArtifacts();
  }
}
