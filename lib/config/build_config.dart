import 'package:flutter/foundation.dart';

enum BuildEnv { dev, prod }

/// 构建环境配置。
///
/// 构建环境配置。
class BuildConfig {
  BuildConfig._();

  static const String _rawAppEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String _rawDebugPanelPassword = String.fromEnvironment(
    'DEBUG_PANEL_PASSWORD',
    defaultValue: '',
  );

  static BuildEnv parseAppEnv(String env) {
    switch (env.trim().toLowerCase()) {
      case 'prod':
      case 'production':
      case 'release':
        return BuildEnv.prod;
      case 'dev':
      case 'debug':
      default:
        return BuildEnv.dev;
    }
  }

  static final BuildEnv currentEnv = parseAppEnv(_rawAppEnv);

  static bool get isDev => currentEnv == BuildEnv.dev;
  static bool get isProd => currentEnv == BuildEnv.prod;

  static String get envName => currentEnv.name;
  static String get rawAppEnv => _rawAppEnv;

  /// 调试面板口令。未通过 --dart-define 配置时为空，调试入口不可用。
  static String get debugPanelPassword {
    if (!kDebugMode) {
      return '';
    }
    return _rawDebugPanelPassword.trim();
  }
}
