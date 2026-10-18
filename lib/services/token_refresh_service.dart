import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'session_store.dart';
import 'log_service.dart';

enum TokenRefreshStatus {
  refreshed,
  invalidCredentials,
  networkUnavailable,
  unexpectedError,
}

class TokenRefreshResult {
  final TokenRefreshStatus status;
  final String? message;

  const TokenRefreshResult(this.status, {this.message});

  bool get isRefreshed => status == TokenRefreshStatus.refreshed;
  bool get isInvalidCredentials =>
      status == TokenRefreshStatus.invalidCredentials;
  bool get isNetworkUnavailable =>
      status == TokenRefreshStatus.networkUnavailable;
}

/// 令牌刷新服务
///
/// 负责检测令牌过期并自动尝试重新登录
class TokenRefreshService {
  final SessionStore _store = SessionStore();
  final AuthService _auth = AuthService();
  final LogService _logger = LogService();

  // 静态变量用于防止并发刷新
  static bool _isRefreshing = false;
  static Future<TokenRefreshResult>? _ongoingRefreshFuture;
  static TokenRefreshResult _lastRefreshResult = const TokenRefreshResult(
    TokenRefreshStatus.unexpectedError,
  );

  static Future<TokenRefreshResult?> waitForOngoingRefresh() async {
    final future = _ongoingRefreshFuture;
    if (future == null) {
      return null;
    }
    return future;
  }

  /// 尝试重新登录
  ///
  /// 当访问令牌过期时，使用本地保存的用户名密码自动重新登录
  /// 返回值: 重新登录是否成功
  Future<TokenRefreshResult> tryRefreshToken() async {
    final stopwatch = Stopwatch()..start();
    // 如果正在刷新，等待结果
    if (_isRefreshing) {
      debugPrint('[令牌刷新] 正在进行中，等待结果...');
      await _logger.logXgTrace(
        const XgTraceLogEntry(
          phase: 'token_refresh',
          event: 'wait_existing_refresh',
          module: 'school_auth',
          requestKey: 'token_refresh',
          result: 'reused',
        ),
      );
      final existingFuture = _ongoingRefreshFuture;
      final refreshResult = existingFuture == null
          ? _lastRefreshResult
          : await existingFuture;
      await _logger.logXgTrace(
        XgTraceLogEntry(
          phase: 'token_refresh',
          event: 'wait_existing_refresh_finished',
          module: 'school_auth',
          requestKey: 'token_refresh',
          elapsedMs: stopwatch.elapsedMilliseconds,
          result: refreshResult.status.name,
        ),
      );
      return refreshResult;
    }

    _isRefreshing = true;
    _lastRefreshResult = const TokenRefreshResult(
      TokenRefreshStatus.unexpectedError,
    );
    final completer = Completer<TokenRefreshResult>();
    _ongoingRefreshFuture = completer.future;

    TokenRefreshResult finishRefresh(TokenRefreshResult result) {
      _lastRefreshResult = result;
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    }

    try {
      await _logger.logXgTrace(
        XgTraceLogEntry(
          phase: 'token_refresh',
          event: 'refresh_started',
          module: 'school_auth',
          requestKey: 'token_refresh',
          result: 'started',
        ),
      );
      final username = await _store.getUsername();
      final password = await _store.getPassword();

      if (username == null ||
          password == null ||
          username.isEmpty ||
          password.isEmpty) {
        debugPrint('[令牌刷新] 本地未保存用户名密码，无法自动重新登录');
        await _logger.log('令牌刷新', '本地未保存用户名密码，无法自动重新登录');
        const refreshResult = TokenRefreshResult(
          TokenRefreshStatus.invalidCredentials,
          message: '本地未保存用户名密码',
        );
        await _logger.logXgTrace(
          XgTraceLogEntry(
            phase: 'token_refresh',
            event: 'refresh_finished',
            module: 'school_auth',
            requestKey: 'token_refresh',
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: refreshResult.status.name,
            reason: 'missing_credentials',
          ),
        );
        return finishRefresh(refreshResult);
      }

      debugPrint('[令牌刷新] 尝试使用本地保存的用户名密码重新登录');
      final result = await _auth.login(username: username, password: password);

      if (result.success && result.accessToken != null) {
        // 保存新的访问令牌
        await _store.saveAccessToken(result.accessToken!);

        // 重新获取并保存用户信息
        try {
          final info = await _auth.getUserInfo(result.accessToken!);
          await _store.saveUserInfo(info);
          await _store.saveDisplayName(info.displayName);
          await _store.saveUserInfoDetails(
            college: info.ouName,
            className: info.className,
          );
        } catch (e) {
          debugPrint('[令牌刷新] 获取用户信息失败，但令牌已刷新: $e');
        }

        debugPrint('[令牌刷新] 重新登录成功');
        const refreshResult = TokenRefreshResult(TokenRefreshStatus.refreshed);
        await _logger.logXgTrace(
          XgTraceLogEntry(
            phase: 'token_refresh',
            event: 'refresh_finished',
            module: 'school_auth',
            requestKey: 'token_refresh',
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: refreshResult.status.name,
          ),
        );
        return finishRefresh(refreshResult);
      } else {
        debugPrint('[令牌刷新] 重新登录失败: ${result.error}');
        await _logger.log('令牌刷新', '重新登录失败: ${result.error}');
        final refreshResult = _classifyRefreshFailure(result.error);
        await _logger.log(
          '令牌刷新',
          '失败分类结果: ${refreshResult.status.name}, message=${refreshResult.message ?? "null"}',
        );
        await _logger.logXgTrace(
          XgTraceLogEntry(
            phase: 'token_refresh',
            event: 'refresh_finished',
            module: 'school_auth',
            requestKey: 'token_refresh',
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: refreshResult.status.name,
            reason: refreshResult.message,
          ),
        );
        return finishRefresh(refreshResult);
      }
    } on DioException catch (e) {
      debugPrint('[令牌刷新] 网络请求出错: $e');
      await _logger.log('令牌刷新', '网络请求出错: ${e.message}');
      const refreshResult = TokenRefreshResult(
        TokenRefreshStatus.networkUnavailable,
      );
      await _logger.log('令牌刷新', '失败分类结果: networkUnavailable');
      await _logger.logXgTrace(
        XgTraceLogEntry(
          phase: 'token_refresh',
          event: 'refresh_finished',
          module: 'school_auth',
          requestKey: 'token_refresh',
          elapsedMs: stopwatch.elapsedMilliseconds,
          result: refreshResult.status.name,
          reason: e.message,
        ),
      );
      return finishRefresh(refreshResult);
    } catch (e) {
      debugPrint('[令牌刷新] 重新登录过程出错: $e');
      await _logger.log('令牌刷新', '重新登录过程出错: $e');
      final refreshResult = TokenRefreshResult(
        TokenRefreshStatus.unexpectedError,
        message: e.toString(),
      );
      await _logger.log(
        '令牌刷新',
        '失败分类结果: unexpectedError, message=${refreshResult.message}',
      );
      await _logger.logXgTrace(
        XgTraceLogEntry(
          phase: 'token_refresh',
          event: 'refresh_finished',
          module: 'school_auth',
          requestKey: 'token_refresh',
          elapsedMs: stopwatch.elapsedMilliseconds,
          result: refreshResult.status.name,
          reason: refreshResult.message,
        ),
      );
      return finishRefresh(refreshResult);
    } finally {
      if (!completer.isCompleted) {
        completer.complete(_lastRefreshResult);
      }
      _isRefreshing = false;
      _ongoingRefreshFuture = null;
    }
  }

  TokenRefreshResult _classifyRefreshFailure(String? error) {
    if (error == null || error.isEmpty) {
      return const TokenRefreshResult(TokenRefreshStatus.unexpectedError);
    }
    if (error == 'network_error') {
      return const TokenRefreshResult(TokenRefreshStatus.networkUnavailable);
    }
    if (error == 'Bad credentials' ||
        error == 'invalid_captcha' ||
        error == 'login_failed_user_locked' ||
        error.startsWith('login_failed_will_lock_')) {
      return TokenRefreshResult(
        TokenRefreshStatus.invalidCredentials,
        message: error,
      );
    }
    return TokenRefreshResult(
      TokenRefreshStatus.unexpectedError,
      message: error,
    );
  }

  /// 检查并处理401错误（令牌过期）
  ///
  /// 如果是401错误，自动尝试刷新令牌
  /// 返回值: 是否成功处理了错误
  Future<TokenRefreshResult> handleTokenExpired(DioException e) async {
    if (e.response?.statusCode == 401) {
      debugPrint('[令牌刷新] 检测到访问令牌已过期');
      await _logger.log('令牌刷新', '访问令牌过期');
      return tryRefreshToken();
    }
    return const TokenRefreshResult(TokenRefreshStatus.unexpectedError);
  }
}
