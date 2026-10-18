import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_urls.dart';
import 'session_store.dart';

class CampusServiceUnavailableException implements Exception {
  final String serviceName;
  final Object? cause;

  const CampusServiceUnavailableException(this.serviceName, {this.cause});

  @override
  String toString() {
    if (cause == null) {
      return '$serviceName暂不可用';
    }
    return '$serviceName暂不可用: $cause';
  }
}

class CachedSessionEligibilityResult {
  final bool canEnter;
  final String? reason;

  const CachedSessionEligibilityResult._({required this.canEnter, this.reason});

  const CachedSessionEligibilityResult.allowed() : this._(canEnter: true);

  const CachedSessionEligibilityResult.denied(String reason)
    : this._(canEnter: false, reason: reason);
}

class CampusAccessService {
  CampusAccessService({SessionStore? store}) : _store = store ?? SessionStore();

  static final Set<String> _campusHosts = <String>{
    Uri.parse(ApiUrls.ssoBaseUrl).host,
    Uri.parse(ApiUrls.jwBaseUrl).host,
    Uri.parse(ApiUrls.jwWebUrl).host,
    Uri.parse(ApiUrls.xgBaseUrl).host,
    Uri.parse(ApiUrls.eipBaseUrl).host,
  };

  final SessionStore _store;

  Future<CachedSessionEligibilityResult> evaluateCachedSessionEligibility(
    String username,
    String password,
  ) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      return const CachedSessionEligibilityResult.denied('请输入账号和密码后再试。');
    }

    final savedUsername = (await _store.getUsername())?.trim() ?? '';
    if (savedUsername.isEmpty || savedUsername != normalizedUsername) {
      return const CachedSessionEligibilityResult.denied(
        '当前设备没有该账号的本机登录记录，请先在联网状态下成功登录一次。',
      );
    }

    final savedPassword = await _store.getPassword();
    if (savedPassword == null || savedPassword.isEmpty) {
      return const CachedSessionEligibilityResult.denied(
        '当前设备未保存登录凭据，请先在联网状态下成功登录一次。',
      );
    }

    if (savedPassword != password) {
      return const CachedSessionEligibilityResult.denied(
        '请输入该设备上已记住的密码后再进入应用。',
      );
    }

    final hasCachedProfile =
        await _store.getUserInfo() != null ||
        ((await _store.getDisplayName())?.isNotEmpty ?? false) ||
        ((await _store.getAccessToken())?.isNotEmpty ?? false);
    if (!hasCachedProfile) {
      return const CachedSessionEligibilityResult.denied(
        '当前设备缺少本地资料缓存，请先在联网状态下成功登录一次。',
      );
    }

    return const CachedSessionEligibilityResult.allowed();
  }

  Future<bool> canEnterWithCachedSession(
    String username,
    String password,
  ) async {
    final result = await evaluateCachedSessionEligibility(username, password);
    return result.canEnter;
  }

  static bool isCampusServiceUrl(String url) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || trimmedUrl.startsWith('/')) {
      return false;
    }

    try {
      final uri = Uri.parse(trimmedUrl);
      if (!uri.hasScheme || uri.host.isEmpty) {
        return false;
      }
      return _campusHosts.contains(uri.host);
    } catch (_) {
      return false;
    }
  }

  static bool isCampusNetworkUnavailableError(Object error) {
    if (error is TimeoutException) {
      return true;
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError ||
          (statusCode != null && statusCode >= 500);
    }

    final message = error.toString();
    return message.contains('TimeoutException') ||
        message.contains('connection timeout') ||
        message.contains('Connection timed out') ||
        message.contains('SocketException') ||
        message.contains('connectionError') ||
        message.contains('receiveTimeout') ||
        message.contains('sendTimeout') ||
        message.contains('status code of 500') ||
        message.contains('HTTP 500');
  }

  static String extractReadableMessage(Object error) {
    var message = error.toString().trim();
    while (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }
    return message;
  }

  static String toUserFacingErrorMessage(
    Object error, {
    String fallback = '操作失败，请稍后重试',
    String networkMessage = '网络连接异常，请稍后重试',
    String campusNetworkMessage = '校园网服务暂不可用，请稍后重试',
    String sessionExpiredMessage = '登录状态已失效，请重新登录',
  }) {
    final readableMessage = extractReadableMessage(error);
    if (readableMessage.isEmpty) {
      return fallback;
    }

    if (_isSessionExpiredError(error, readableMessage)) {
      return sessionExpiredMessage;
    }

    if (error is CampusServiceUnavailableException ||
        _containsCampusServiceUnavailableMessage(readableMessage)) {
      return campusNetworkMessage;
    }

    if (isCampusNetworkUnavailableError(error)) {
      return networkMessage;
    }

    if (!_looksTechnical(readableMessage)) {
      return readableMessage;
    }

    return fallback;
  }

  static bool _isSessionExpiredError(Object error, String readableMessage) {
    if (error is DioException && error.response?.statusCode == 401) {
      return true;
    }

    final normalized = readableMessage.toLowerCase();
    return normalized.contains('登录状态已失效') ||
        normalized.contains('未找到访问令牌') ||
        normalized.contains('未获取到统一认证token') ||
        normalized.contains('未登录，请重新登录') ||
        normalized.contains('401 unauthorized');
  }

  static bool _containsCampusServiceUnavailableMessage(String message) {
    return message.contains('校园网') ||
        message.contains('课表暂不可用') ||
        message.contains('智慧学工暂不可用') ||
        message.contains('融合门户公告暂不可用');
  }

  static bool _looksTechnical(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('dioexception') ||
        normalized.contains('socketexception') ||
        normalized.contains('timeoutexception') ||
        normalized.contains('formatexception') ||
        normalized.contains('clientexception') ||
        normalized.contains('connectionerror') ||
        normalized.contains('receivetimeout') ||
        normalized.contains('sendtimeout') ||
        normalized.contains('status code of') ||
        normalized.contains('xmlhttprequest') ||
        normalized.contains('stack trace') ||
        message.contains('Instance of') ||
        message.contains('type \'');
  }
}
