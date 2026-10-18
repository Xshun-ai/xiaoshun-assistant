import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';

import '../../constants/api_urls.dart';

class SsoFlowSupport {
  static PersistCookieJar? _globalJar;
  static const List<String> _invalidTokenFragments = <String>[
    '<',
    '>',
    '"',
    "'",
    'class=',
    'linkedUuid',
    'list-group-item',
    '<html',
    '<body',
    '<!DOCTYPE',
  ];
  static const Duration _mobileTokenSafetyWindow = Duration(minutes: 1);

  static Future<PersistCookieJar> getGlobalJar() async {
    if (_globalJar != null) return _globalJar!;
    final appDocDir = await getApplicationDocumentsDirectory();
    _globalJar = PersistCookieJar(
      storage: FileStorage('${appDocDir.path}/.cookies/xg_global'),
    );
    return _globalJar!;
  }

  static Map<String, String> getCommonHeaders(String appName) {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
      'Referer':
          '${ApiUrls.xgBaseUrl}/xsfw/sys/'
          '$appName/*default/index.do?THEME=purple',
    };
  }

  static bool isLikelyAccountSelectionPage(String body) {
    return body.contains('linkedUuid') && body.contains('list-group-item');
  }

  static String? extractAccountSelectionUrlForUsername(
    String body, {
    required String username,
  }) {
    if (!isLikelyAccountSelectionPage(body)) {
      return null;
    }

    final document = html_parser.parse(body);
    final anchors = document.querySelectorAll('a');
    for (final anchor in anchors) {
      final href = anchor.attributes['href'];
      final text = anchor.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (href == null || href.isEmpty) {
        continue;
      }
      if (!href.contains('linkedUuid=')) {
        continue;
      }
      if (text == username) {
        return href;
      }
    }
    return null;
  }

  static bool isValidMobileToken(String? token) {
    if (token == null) {
      return false;
    }

    if (token.isEmpty || token.trim() != token) {
      return false;
    }

    if (RegExp(r'[\r\n\t ]').hasMatch(token)) {
      return false;
    }

    final lowerToken = token.toLowerCase();
    for (final fragment in _invalidTokenFragments) {
      if (lowerToken.contains(fragment.toLowerCase())) {
        return false;
      }
    }

    final expiresAt = _extractMobileTokenExpiresAt(token);
    if (expiresAt == null) {
      return false;
    }

    return expiresAt.isAfter(
      DateTime.now().toUtc().add(_mobileTokenSafetyWindow),
    );
  }

  static bool isCorruptedMobileTokenError(Object error) {
    final message = error.toString();
    return message.contains('Invalid HTTP header field value') ||
        message.contains('FormatException: Invalid HTTP header field value');
  }

  static bool shouldRefreshMobileTokenForError(Object error) {
    if (isCorruptedMobileTokenError(error)) {
      return true;
    }

    final message = error.toString();
    return message.contains('status code of 500') ||
        message.contains('status code of 401') ||
        message.contains('status code of 403') ||
        message.contains('状态码: 500') ||
        message.contains('状态码: 401') ||
        message.contains('状态码: 403');
  }

  static DateTime? _extractMobileTokenExpiresAt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }

      final expRaw = decoded['exp'];
      final expSeconds = expRaw is num
          ? expRaw.toInt()
          : int.tryParse('$expRaw');
      if (expSeconds == null || expSeconds <= 0) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(
        expSeconds * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }
}
