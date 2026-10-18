import 'dart:async';

import 'package:dio/dio.dart';

import '../../constants/api_urls.dart';
import '../log_service.dart';
import 'sso_models.dart';

class SsoRequestAdapter {
  static const Duration navigationRequestTimeout = Duration(seconds: 15);
  static const Duration navigationFlowTimeout = Duration(seconds: 45);
  static const Duration xgNavigationRequestTimeout = Duration(seconds: 5);
  static const Duration xgNavigationFlowTimeout = Duration(seconds: 10);

  static String? extractMobileTokenFromUrl(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(url);
      final queryToken = uri.queryParameters['token'];
      if (queryToken != null && queryToken.isNotEmpty) {
        return queryToken;
      }

      final fragment = uri.fragment;
      if (fragment.isNotEmpty) {
        final questionMarkIndex = fragment.indexOf('?');
        if (questionMarkIndex != -1 &&
            questionMarkIndex < fragment.length - 1) {
          final query = fragment.substring(questionMarkIndex + 1);
          final params = Uri.splitQueryString(query);
          final fragmentToken = params['token'];
          if (fragmentToken != null && fragmentToken.isNotEmpty) {
            return fragmentToken;
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

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

  static bool isSessionInvalidStatusCode(int? statusCode) {
    return statusCode == 302 || statusCode == 403;
  }

  static bool isLoginHtmlContent(dynamic data) {
    final text = data?.toString() ?? '';
    if (text.isEmpty) {
      return false;
    }

    final hasHtml =
        text.contains('<!DOCTYPE html') ||
        text.contains('<html') ||
        text.contains('<head') ||
        text.contains('<body');
    if (!hasHtml) {
      return false;
    }

    return text.contains('统一身份认证') ||
        text.contains('统一认证') ||
        text.contains('authserver') ||
        text.contains('cas') ||
        text.contains('login') ||
        text.contains('Login') ||
        text.contains('pwd') ||
        text.contains('password');
  }

  static bool isSessionInvalidResponse(Response response) {
    return isSessionInvalidStatusCode(response.statusCode) ||
        isLoginHtmlContent(response.data);
  }

  static Options buildNavigationOptions(Options? options) {
    return Options(
      headers: Map<String, dynamic>.from(options?.headers ?? const {}),
      responseType: ResponseType.plain,
      followRedirects: false,
      validateStatus: (code) => code != null && code < 400,
      contentType: options?.contentType,
      extra: options?.extra,
    );
  }

  static bool shouldStopAtClientUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.fragment.isNotEmpty || url.contains('#/');
    } catch (_) {
      return url.contains('#/');
    }
  }

  static bool isXgLandingPage(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host == 'xg.sdpt.edu.cn' &&
          uri.path == '/xsfw/sys/xggzptapp/index.do' &&
          uri.queryParameters.containsKey('ticket');
    } catch (_) {
      return false;
    }
  }

  static String buildXgDefaultIndexUrl(String url) {
    final uri = Uri.parse(url);
    return uri
        .replace(
          path: '/xsfw/sys/xggzptapp/*default/index.do',
          queryParameters: <String, String>{'min': '1'},
        )
        .toString();
  }

  static String resolveUrl(String baseUrl, String location) {
    try {
      final base = Uri.parse(baseUrl);
      final locUri = Uri.parse(location);
      final resolved = base.resolveUri(locUri);
      return resolved.toString();
    } catch (_) {
      if (location.startsWith('http://') || location.startsWith('https://')) {
        return location;
      }
      return '${ApiUrls.ssoBaseUrl}$location';
    }
  }

  static Future<SsoFlowResult> followSsoNavigation({
    required Dio dio,
    required String startUrl,
    required String username,
    required String? Function(String body, {required String username})
    extractAccountSelectionUrlForUsername,
    Options? options,
    int maxRedirects = 20,
    Duration requestTimeout = navigationRequestTimeout,
    Duration flowTimeout = navigationFlowTimeout,
  }) async {
    return Future<SsoFlowResult>(() async {
      final traceStopwatch = Stopwatch()..start();
      var currentUrl = startUrl;
      Response resp = await dio
          .get(currentUrl, options: buildNavigationOptions(options))
          .timeout(requestTimeout);

      for (var i = 0; i < maxRedirects; i++) {
        final status = resp.statusCode ?? 0;
        await LogService().logXgTrace(
          XgTraceLogEntry(
            phase: 'sso',
            event: 'navigation_hop',
            module: 'sso',
            requestKey: 'sso_navigation',
            elapsedMs: traceStopwatch.elapsedMilliseconds,
            result: 'ok',
            extra: <String, dynamic>{
              'hop': i + 1,
              'statusCode': status,
              'url': LogService().summarizeTraceUrl(currentUrl),
            },
          ),
        );
        await LogService().log(
          '统一认证',
          'SSO请求[${i + 1}] URL: ${LogService().sanitizeSensitiveUrl(currentUrl)}，状态码: $status',
        );

        if (status >= 300 && status < 400) {
          final loc = resp.headers.value('location');
          if (loc == null || loc.isEmpty) {
            await LogService().logXgTrace(
              XgTraceLogEntry(
                phase: 'sso',
                event: 'navigation_missing_location',
                module: 'sso',
                requestKey: 'sso_navigation',
                elapsedMs: traceStopwatch.elapsedMilliseconds,
                result: 'error',
              ),
            );
            await LogService().log(
              '统一认证',
              '重定向响应缺少Location头，停止',
            );
            break;
          }
          final nextUrl = resolveUrl(currentUrl, loc);
          await LogService().logXgTrace(
            XgTraceLogEntry(
              phase: 'sso',
              event: 'navigation_redirect',
              module: 'sso',
              requestKey: 'sso_navigation',
              elapsedMs: traceStopwatch.elapsedMilliseconds,
              result: 'ok',
              extra: <String, dynamic>{
                'hop': i + 1,
                'nextUrl': LogService().summarizeTraceUrl(nextUrl),
              },
            ),
          );
          await LogService().log(
            '统一认证',
            '跟随重定向到: ${LogService().sanitizeSensitiveUrl(nextUrl)}',
          );
          if (isXgLandingPage(nextUrl)) {
            final defaultUrl = buildXgDefaultIndexUrl(nextUrl);
            await LogService().logXgTrace(
              XgTraceLogEntry(
                phase: 'sso',
                event: 'navigation_xg_default_redirect',
                module: 'sso',
                requestKey: 'sso_navigation',
                elapsedMs: traceStopwatch.elapsedMilliseconds,
                result: 'ok',
                extra: <String, dynamic>{
                  'hop': i + 1,
                  'nextUrl': LogService().summarizeTraceUrl(defaultUrl),
                },
              ),
            );
            await LogService().log(
              '统一认证',
              '检测到智慧学工落地页，补跳默认首页: ${LogService().sanitizeSensitiveUrl(defaultUrl)}',
            );
            currentUrl = defaultUrl;
            resp = await dio
                .get(currentUrl, options: buildNavigationOptions(options))
                .timeout(requestTimeout);
            continue;
          }
          currentUrl = nextUrl;
          resp = await dio
              .get(currentUrl, options: buildNavigationOptions(options))
              .timeout(requestTimeout);
          continue;
        }

        if (status == 200) {
          final body = resp.data?.toString() ?? '';
          final accountUrl = extractAccountSelectionUrlForUsername(
            body,
            username: username,
          );
          if (accountUrl != null) {
            final nextUrl = resolveUrl(currentUrl, accountUrl);
            await LogService().logXgTrace(
              XgTraceLogEntry(
                phase: 'sso',
                event: 'navigation_account_select',
                module: 'sso',
                requestKey: 'sso_navigation',
                elapsedMs: traceStopwatch.elapsedMilliseconds,
                result: 'ok',
                extra: <String, dynamic>{
                  'hop': i + 1,
                  'nextUrl': LogService().summarizeTraceUrl(nextUrl),
                },
              ),
            );
            await LogService().log(
              '统一认证',
              '检测到账号选择页，已匹配学号 $username 并继续跳转: ${LogService().sanitizeSensitiveUrl(nextUrl)}',
            );
            currentUrl = nextUrl;
            resp = await dio
                .get(currentUrl, options: buildNavigationOptions(options))
                .timeout(requestTimeout);
            continue;
          }

          final jsRedirect = extractJsRedirectUrl(body);
          if (jsRedirect != null) {
            final nextUrl = resolveUrl(currentUrl, jsRedirect);
            await LogService().logXgTrace(
              XgTraceLogEntry(
                phase: 'sso',
                event: 'navigation_script_redirect',
                module: 'sso',
                requestKey: 'sso_navigation',
                elapsedMs: traceStopwatch.elapsedMilliseconds,
                result: 'ok',
                extra: <String, dynamic>{
                  'hop': i + 1,
                  'nextUrl': LogService().summarizeTraceUrl(nextUrl),
                },
              ),
            );
            await LogService().log(
              '统一认证',
              '检测到页面脚本跳转: ${LogService().sanitizeSensitiveUrl(nextUrl)}',
            );
            if (shouldStopAtClientUrl(nextUrl)) {
              await LogService().logXgTrace(
                XgTraceLogEntry(
                  phase: 'sso',
                  event: 'navigation_finished',
                  module: 'sso',
                  requestKey: 'sso_navigation',
                  elapsedMs: traceStopwatch.elapsedMilliseconds,
                  result: 'ok',
                  extra: <String, dynamic>{
                    'finalUrl': LogService().summarizeTraceUrl(nextUrl),
                  },
                ),
              );
              return SsoFlowResult(response: resp, finalUrl: nextUrl);
            }
            currentUrl = nextUrl;
            resp = await dio
                .get(currentUrl, options: buildNavigationOptions(options))
                .timeout(requestTimeout);
            continue;
          }
        }

        break;
      }

      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'sso',
          event: 'navigation_finished',
          module: 'sso',
          requestKey: 'sso_navigation',
          elapsedMs: traceStopwatch.elapsedMilliseconds,
          result: 'ok',
          extra: <String, dynamic>{
            'finalUrl': LogService().summarizeTraceUrl(currentUrl),
            'statusCode': resp.statusCode,
          },
        ),
      );
      return SsoFlowResult(response: resp, finalUrl: currentUrl);
    }).timeout(flowTimeout);
  }
}
