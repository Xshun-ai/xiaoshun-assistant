import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 网络传输配置。
class SecurityUtils {
  SecurityUtils._();

  /// 配置 Dio 的 HTTPS 证书校验。
  ///
  /// [allowSelfSigned] 仅用于明确需要自签名证书的调试场景。
  static void configureDioSecurity(
    Dio dio, {
    bool allowSelfSigned = false,
  }) {
    if (dio.httpClientAdapter is IOHttpClientAdapter) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) =>
                allowSelfSigned;
        return client;
      };
    }
  }
}
