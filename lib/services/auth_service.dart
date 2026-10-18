import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_urls.dart';
import '../models/user_info.dart';
import '../utils/sm2_crypto.dart';
import 'session_store.dart';
import 'portal_announcement_service.dart';
import 'sso_service.dart';
import 'log_service.dart';

class LoginResult {
  final bool success;
  final String? accessToken;
  final String? error;
  final String? captchaImageBase64;
  final String? captchaCode;
  LoginResult({
    required this.success,
    this.accessToken,
    this.error,
    this.captchaImageBase64,
    this.captchaCode,
  });
}

enum AccessTokenValidationState { valid, invalid, networkError }

class AccessTokenValidationResult {
  final AccessTokenValidationState state;
  final int? statusCode;
  final Object? error;

  const AccessTokenValidationResult._(
    this.state, {
    this.statusCode,
    this.error,
  });

  const AccessTokenValidationResult.valid()
    : this._(AccessTokenValidationState.valid);

  const AccessTokenValidationResult.invalid({int? statusCode, Object? error})
    : this._(
        AccessTokenValidationState.invalid,
        statusCode: statusCode,
        error: error,
      );

  const AccessTokenValidationResult.networkError({Object? error})
    : this._(AccessTokenValidationState.networkError, error: error);

  bool get isValid => state == AccessTokenValidationState.valid;
  bool get isNetworkError => state == AccessTokenValidationState.networkError;
}

class AuthService {
  static const Duration _campusAuthRequestTimeout = Duration(seconds: 5);

  /// 网络客户端（允许 <400 的状态码，避免 303 抛异常）
  final Dio _dio;
  AuthService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              validateStatus: (code) => code != null && code < 400,
              // 登录链路需要尽快失败，避免校园网不可达时长时间阻塞离线入口。
              connectTimeout: _campusAuthRequestTimeout,
              receiveTimeout: _campusAuthRequestTimeout,
              sendTimeout: _campusAuthRequestTimeout,
            ),
          );

  bool _isTransientNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  Future<Map<String, String>> _getSm2Key() async {
    final resp = await _dio.post(
      ApiUrls.ssoSm2KeyUrl,
      data: {},
      options: Options(
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Referer': ApiUrls.ssoReferer,
        },
      ),
    );
    final data = resp.data['data'] ?? resp.data;
    final publicKey = data['publicKey'] as String;
    final code = data['code'] as String;
    return {'publicKey': publicKey, 'code': code};
  }

  /// 轻量探测校园网统一认证是否可达。
  ///
  /// 仅用于“重试联网”场景，先判断校园网是否真的恢复，再决定是否提示重新登录。
  Future<bool> probeCampusConnectivity({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final resp = await _dio
          .post(
            ApiUrls.ssoSm2KeyUrl,
            data: {},
            options: Options(
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Referer': ApiUrls.ssoReferer,
              },
              validateStatus: (status) {
                return status != null && status < 500;
              },
            ),
          )
          .timeout(timeout);

      return resp.statusCode != null;
    } on TimeoutException {
      return false;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (_isTransientNetworkError(e) ||
          (statusCode != null && statusCode >= 500)) {
        return false;
      }
      return statusCode != null;
    } catch (_) {
      return false;
    }
  }

  Future<LoginResult> login({
    required String username,
    required String password,
    String? capCode,
    String? capText,
  }) async {
    try {
      debugPrint('DEBUG: 开始登录流程...');

      // 1. 获取 SM2 公钥
      final key = await _getSm2Key();
      debugPrint('DEBUG: 成功获取 SM2 公钥');

      // 2. 加密密码（使用 SM2 工具类）
      final enc = Sm2Crypto.encrypt(key['publicKey']!, password);
      debugPrint('DEBUG: 密码加密完成');

      // 3. 构造登录请求参数
      final body = {
        'client_id': 'a27231f36a6611250e4f5461a9d8802eRxmVpnmaYf4',
        'grant_type': 'password',
        'scope': 'read',
        'username': username,
        'password': enc,
        '_enterprise_id': 'sdxy',
        'sm2_code': key['code'],
        'auto_login': false,
      };

      // 如果有验证码，添加到请求参数中
      if (capCode != null && capText != null) {
        body['cap_code'] = capCode;
        body['cap_text'] = capText;
        debugPrint('DEBUG: 附带验证码提交');
      }

      debugPrint('DEBUG: 发送登录请求...');
      final resp = await _dio.post(
        ApiUrls.ssoLoginUrl,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
            'Referer': ApiUrls.ssoReferer,
          },
        ),
      );

      debugPrint('DEBUG: 登录响应状态码: ${resp.statusCode}');

      final data = resp.data['data'] ?? resp.data;
      final token = data['access_token'] ?? resp.data['access_token'];

      if (token is String && token.isNotEmpty) {
        debugPrint('DEBUG: 登录成功，获取到 Access Token');
        return LoginResult(success: true, accessToken: token);
      }

      debugPrint('DEBUG: 登录失败，未找到 Access Token');
      return LoginResult(success: false, error: 'unknown_error');
    } on DioException catch (e) {
      debugPrint('DEBUG: 网络请求异常: ${e.message}');
      if (e.response != null) {
        debugPrint('DEBUG: 错误响应状态码: ${e.response?.statusCode}');
        if (kDebugMode) {
          debugPrint('DEBUG: 错误响应数据: ${e.response?.data}');
        }
      }

      if (e.response != null && e.response!.data is Map) {
        final m = e.response!.data as Map;
        final msg = m['message'] as String?;

        // 处理验证码错误或密码错误（预判需要验证码），自动刷新验证码
        if (msg == 'invalid_captcha' ||
            msg == 'Bad credentials' ||
            (msg != null && msg.startsWith('login_failed_will_lock_'))) {
          debugPrint('DEBUG: 检测到需要验证码的情况 ($msg)，正在刷新验证码...');
          try {
            final cap = await fetchCaptcha();
            return LoginResult(
              success: false,
              error: msg ?? 'login_failed',
              captchaImageBase64: cap['captcha'],
              captchaCode: cap['code'],
            );
          } catch (e) {
            debugPrint('DEBUG: 刷新验证码失败: $e');
            // 即使刷新失败，也要返回原始错误信息
            return LoginResult(success: false, error: msg ?? 'login_failed');
          }
        }
        return LoginResult(success: false, error: msg ?? 'login_failed');
      }
      return LoginResult(success: false, error: 'network_error');
    } catch (e, stack) {
      debugPrint('DEBUG: 未知错误: $e');
      debugPrint('DEBUG: 堆栈跟踪: $stack');
      return LoginResult(success: false, error: 'system_error');
    }
  }

  Future<Map<String, String>> fetchCaptcha() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final url =
        '${ApiUrls.ssoBaseUrl}/api/public/bff/v1.2/one_time_login/captcha?_enterprise_id=sdxy&timestamp=$ts';
    final resp = await _dio.get(
      url,
      options: Options(headers: {'Referer': ApiUrls.ssoReferer}),
    );
    final data = resp.data['data'] ?? resp.data;
    return {
      'code': data['code'] as String,
      'captcha': data['captcha'] as String,
    };
  }

  /// 轻量校验 Access Token 是否仍有效。
  ///
  /// 启动页只需要区分三种结果：
  /// 1. Token 有效
  /// 2. Token 已失效（401/403）
  /// 3. 校园网/网络不可达（超时、连接失败、5xx）
  Future<AccessTokenValidationResult> validateAccessToken(
    String accessToken, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final resp = await _dio
          .get(
            '${ApiUrls.ssoUserInfoUrl}?_lang=zh_CN',
            options: Options(
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Referer': ApiUrls.ssoEndUserReferer,
              },
              validateStatus: (status) {
                return status != null && status < 500;
              },
            ),
          )
          .timeout(timeout);

      if (resp.statusCode == 200 &&
          (resp.data['success'] == true || resp.data['code'] == '200')) {
        return const AccessTokenValidationResult.valid();
      }

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return AccessTokenValidationResult.invalid(statusCode: resp.statusCode);
      }

      return AccessTokenValidationResult.invalid(
        statusCode: resp.statusCode,
        error: resp.data,
      );
    } on TimeoutException catch (e) {
      return AccessTokenValidationResult.networkError(error: e);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return AccessTokenValidationResult.invalid(
          statusCode: statusCode,
          error: e,
        );
      }

      if (_isTransientNetworkError(e) ||
          (statusCode != null && statusCode >= 500)) {
        return AccessTokenValidationResult.networkError(error: e);
      }

      return AccessTokenValidationResult.invalid(
        statusCode: statusCode,
        error: e,
      );
    } catch (e) {
      return AccessTokenValidationResult.invalid(error: e);
    }
  }

  /// 获取用户信息
  Future<UserInfo> getUserInfo(String accessToken) async {
    try {
      final resp = await _dio.get(
        '${ApiUrls.ssoBaseUrl}/api/bff/v1.2/commons/user_details?_lang=zh_CN',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Referer': ApiUrls.ssoEndUserReferer,
          },
          // 允许 401 错误，以便我们捕获并打印详细信息
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );

      if (resp.statusCode == 200 &&
          (resp.data['success'] == true || resp.data['code'] == '200')) {
        final userInfo = UserInfo.fromJson(resp.data);
        if (kDebugMode) {
          debugPrint(
            'DEBUG: 用户信息解析完成 '
            'username=${userInfo.username}, '
            'displayName=${userInfo.displayName}, '
            'college=${userInfo.ouName}, '
            'className=${userInfo.className}',
          );
        }
        return userInfo;
      } else {
        if (kDebugMode) {
          debugPrint(
            'DEBUG: 获取用户信息失败，状态码: ${resp.statusCode}, 响应: ${resp.data}',
          );
        }
        throw Exception('API Error: ${resp.data['message']}');
      }
    } catch (e) {
      debugPrint('DEBUG: 获取用户信息失败: $e');
      rethrow;
    }
  }

  Future<void> _clearExternalSessions({
    required LogService logger,
    required String action,
  }) async {
    try {
      await PortalAnnouncementService().clearSession();
    } catch (e) {
      await logger.log(action, '清除公告服务会话失败: $e');
    }

    try {
      final jar = await SsoService.getGlobalJar();
      await XgSessionHelper.clearCookies(jar);
    } catch (e) {
      await logger.log(action, '清除统一认证Cookie失败: $e');
    }
  }

  /// 退出登录，清除所有会话和Cookie
  Future<void> logout() async {
    final logger = LogService();
    await logger.log('退出登录', '开始执行完整退出流程...');

    // 1. 清除核心会话数据 (SharedPreferences)
    await SessionStore().clearSession();
    await SessionStore().clearSavedLoginState();
    await logger.log('退出登录', '核心会话数据已清除');

    await _clearExternalSessions(logger: logger, action: '退出登录');

    await logger.log('退出登录', '退出流程完成');
  }

  /// 账号切换时清除旧账号缓存与跨系统会话，但保留登录偏好设置。
  Future<void> clearUserScopedSessionForSwitch() async {
    final logger = LogService();
    await logger.log('账号切换', '检测到账号切换，开始清理旧账号缓存');

    await SessionStore().clearUserScopedData();

    await _clearExternalSessions(logger: logger, action: '账号切换');

    await logger.log('账号切换', '旧账号缓存清理完成');
  }
}
