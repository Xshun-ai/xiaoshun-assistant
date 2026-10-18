import 'dart:async';

import 'package:dio/dio.dart';

enum XgSessionFailureKind {
  moduleExpired,
  baseExpired,
  schoolTokenExpired,
  timeout,
  network,
  unknown,
}

class XgSessionException implements Exception {
  final XgSessionFailureKind kind;
  final String message;
  final Object? cause;

  const XgSessionException({
    required this.kind,
    required this.message,
    this.cause,
  });

  @override
  String toString() {
    if (cause == null) {
      return 'XgSessionException(${kind.name}): $message';
    }
    return 'XgSessionException(${kind.name}): $message, cause=$cause';
  }
}

typedef SessionInvalidResponseFn = bool Function(Response response);
typedef CampusNetworkUnavailableFn = bool Function(Object error);

class SsoErrorMapper {
  static bool isTimeoutError(Object error) {
    if (error is TimeoutException) {
      return true;
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
    }
    return error.toString().contains('TimeoutException');
  }

  static XgSessionException mapToSessionException(
    Object error, {
    required XgSessionFailureKind fallbackKind,
    required String context,
    required SessionInvalidResponseFn isSessionInvalidResponse,
    required CampusNetworkUnavailableFn isCampusNetworkUnavailableError,
  }) {
    if (error is XgSessionException) {
      return error;
    }

    if (error is DioException && error.response != null) {
      final response = error.response!;
      if (isSessionInvalidResponse(response)) {
        return XgSessionException(
          kind: fallbackKind,
          message:
              '$context: status=${response.statusCode}, body=${response.data?.toString() ?? ""}',
          cause: error,
        );
      }
    }

    if (isTimeoutError(error)) {
      return XgSessionException(
        kind: XgSessionFailureKind.timeout,
        message: '$context超时',
        cause: error,
      );
    }

    if (isCampusNetworkUnavailableError(error)) {
      return XgSessionException(
        kind: XgSessionFailureKind.network,
        message: '$context网络异常',
        cause: error,
      );
    }

    return XgSessionException(
      kind: XgSessionFailureKind.unknown,
      message: context,
      cause: error,
    );
  }

  static void throwIfInvalidAuthResponse(
    Response response, {
    required XgSessionFailureKind failureKind,
    required String context,
    required SessionInvalidResponseFn isSessionInvalidResponse,
  }) {
    if (!isSessionInvalidResponse(response)) {
      return;
    }

    throw XgSessionException(
      kind: failureKind,
      message:
          '$context检测到会话失效: status=${response.statusCode}, body=${response.data?.toString() ?? ""}',
    );
  }

  static Future<Response<T>> runAuthRequest<T>(
    Future<Response<T>> Function() request, {
    required XgSessionFailureKind failureKind,
    required String context,
    required SessionInvalidResponseFn isSessionInvalidResponse,
    required CampusNetworkUnavailableFn isCampusNetworkUnavailableError,
  }) async {
    try {
      final response = await request();
      throwIfInvalidAuthResponse(
        response,
        failureKind: failureKind,
        context: context,
        isSessionInvalidResponse: isSessionInvalidResponse,
      );
      return response;
    } catch (e) {
      throw mapToSessionException(
        e,
        fallbackKind: failureKind,
        context: context,
        isSessionInvalidResponse: isSessionInvalidResponse,
        isCampusNetworkUnavailableError: isCampusNetworkUnavailableError,
      );
    }
  }
}
