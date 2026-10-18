/// 学校系统服务地址常量。
///
/// 当前版本只保留学校直连系统需要的地址。
class ApiUrls {
  // 私有构造函数，防止实例化
  ApiUrls._();

  // ==================== SSO 认证服务 ====================
  /// 统一认证基础 URL
  static const String ssoBaseUrl = 'https://authserver.sdpt.edu.cn';

  /// SSO Referer
  static const String ssoReferer =
      'https://authserver.sdpt.edu.cn/frontend/login';

  /// SSO EndUser Referer
  static const String ssoEndUserReferer =
      'https://authserver.sdpt.edu.cn/frontend/enduser/';

  /// 获取 SM2 密钥
  static const String ssoSm2KeyUrl = '$ssoBaseUrl/api/public/bff/v1.2/sm2_key';

  /// 登录认证
  static const String ssoLoginUrl =
      '$ssoBaseUrl/api/public/bff/v1.2/rest_token';

  /// 获取验证码
  static const String ssoCaptchaUrl =
      '$ssoBaseUrl/api/public/bff/v1.2/one_time_login/captcha';

  /// 获取用户信息
  static const String ssoUserInfoUrl =
      '$ssoBaseUrl/api/bff/v1.2/commons/user_details';

  // ==================== 教务系统 (JiaoWu) ====================
  /// 移动端教务系统 API 地址
  static const String jwBaseUrl = 'https://ydjw.sdpt.edu.cn:9001';

  /// 教务系统 Web 地址 (用于 SSO 跳转落地)
  static const String jwWebUrl = 'https://jw.sdpt.edu.cn';

  // ==================== 智慧学工 (XueGong) ====================
  /// 智慧学工基础 URL
  static const String xgBaseUrl = 'https://xg.sdpt.edu.cn';

  /// 智慧学工域名 (用于Cookie Domain)
  static const String xgDomain = 'xg.sdpt.edu.cn';

  // ==================== 融合门户 (EIP) ====================
  /// 融合门户基础 URL
  static const String eipBaseUrl = 'https://eip.sdpt.edu.cn';

  /// 融合门户域名 (用于检查重定向)
  static const String eipDomain = 'eip.sdpt.edu.cn';
}
