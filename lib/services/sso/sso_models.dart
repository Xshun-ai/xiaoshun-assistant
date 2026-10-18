import 'package:dio/dio.dart';

/// SSO结果数据类（包含教务系统Cookie）
class SsoResult {
  /// 教务系统主会话Cookie `bzb_jsxsd`
  final String? bzbJsxsd;

  /// 教务系统负载均衡标识Cookie `SERVERID_jsxsd`
  final String? serverIdJsxsd;

  SsoResult({this.bzbJsxsd, this.serverIdJsxsd});

  /// 是否成功获取到教务系统Cookie
  bool get hasCookies => bzbJsxsd != null && serverIdJsxsd != null;
}

/// 移动端教务系统SSO结果
class MobileSsoResult {
  /// 移动端Token
  final String? token;

  MobileSsoResult({this.token});

  bool get success => token != null;
}

/// 智慧学工首页基础会话结果
class XgBaseSessionResult {
  final String? weu;
  final String? jsessionid;
  final String? route;

  const XgBaseSessionResult({this.weu, this.jsessionid, this.route});

  bool get success => weu != null;
}

/// 兼容旧命名，语义已退化为基础会话结果。
class XgSsoResult extends XgBaseSessionResult {
  final String? roleId;

  const XgSsoResult({super.weu, super.jsessionid, super.route, this.roleId});
}

class XgModule {
  final String appName;
  final String appId;

  const XgModule(this.appName, this.appId);

  static const XgModule activity = XgModule('xshdapp', '4805589443814173');
  static const XgModule evaluation = XgModule(
    'zhcptybbapp',
    '5275772372599202',
  );
}

/// SSO 跟随结果
class SsoFlowResult {
  final Response response;
  final String finalUrl;

  const SsoFlowResult({required this.response, required this.finalUrl});
}
