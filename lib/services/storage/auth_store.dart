import 'package:shared_preferences/shared_preferences.dart';

import 'secret_store.dart';

class AuthStore {
  static const kAccessToken = 'access_token';
  static const kUsername = 'username';
  static const kRememberPassword = 'remember_password';
  static const kBzbJsxsd = 'bzb_jsxsd';
  static const kServerIdJsxsd = 'serverid_jsxsd';
  static const kPassword = 'password';
  static const kAutoLogin = 'auto_login';
  static const kYdjwToken = 'ydjw_token';
  static const kUserInfo = 'user_info_cache';
  static const kScopedSeparator = '__user__';

  Future<void> setAutoLogin(bool autoLogin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAutoLogin, autoLogin);
  }

  Future<bool> getAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kAutoLogin) ?? false;
  }

  Future<void> saveAccessToken(String token) async {
    await SecretStoreBinding.instance.write(kAccessToken, token);
    // 清理旧版本遗留的明文 access token。
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kAccessToken);
  }

  Future<String?> getAccessToken() async {
    final stored = await SecretStoreBinding.instance.read(kAccessToken);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    // 兼容旧版本：把 SharedPreferences 中的明文 token 迁移到安全存储。
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(kAccessToken);
    if (legacy == null || legacy.isEmpty) {
      return null;
    }
    await SecretStoreBinding.instance.write(kAccessToken, legacy);
    await prefs.remove(kAccessToken);
    return legacy;
  }

  Future<void> clearAccessToken() async {
    await SecretStoreBinding.instance.delete(kAccessToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kAccessToken);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUsername, username);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kUsername);
  }

  Future<void> setRememberPassword(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kRememberPassword, remember);
  }

  Future<bool> getRememberPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kRememberPassword) ?? false;
  }

  Future<void> saveJwCookies({
    required String bzbJsxsd,
    required String serverIdJsxsd,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kBzbJsxsd, bzbJsxsd);
    await prefs.setString(kServerIdJsxsd, serverIdJsxsd);
  }

  Future<Map<String, String>?> getJwCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final b = prefs.getString(kBzbJsxsd);
    final s = prefs.getString(kServerIdJsxsd);
    if (b == null || s == null) return null;
    return {'bzb_jsxsd': b, 'SERVERID_jsxsd': s};
  }

  Future<void> savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await SecretStoreBinding.instance.write(kPassword, password);
    // 清理旧版本遗留的明文密码。
    await prefs.remove(kPassword);
  }

  Future<String?> getPassword() async {
    final stored = await SecretStoreBinding.instance.read(kPassword);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    // 兼容旧版本：把 SharedPreferences 中的明文密码迁移到安全存储。
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(kPassword);
    if (legacy == null || legacy.isEmpty) {
      return null;
    }
    await SecretStoreBinding.instance.write(kPassword, legacy);
    await prefs.remove(kPassword);
    return legacy;
  }

  Future<bool> hasRecoverableLoginSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(kUsername)?.trim() ?? '';
    final password = (await getPassword())?.trim() ?? '';
    if (username.isEmpty || password.isEmpty) {
      return false;
    }

    final accessToken = await getAccessToken();
    final userInfo = prefs.getString(kUserInfo);
    return (accessToken != null && accessToken.isNotEmpty) ||
        (userInfo != null && userInfo.isNotEmpty);
  }

  Future<void> clearPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await SecretStoreBinding.instance.delete(kPassword);
    await prefs.remove(kPassword);
  }

  Future<void> saveYdjwToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kYdjwToken, token);
  }

  Future<String?> getYdjwToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kYdjwToken);
  }

  Future<void> clearYdjwToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kYdjwToken);
  }

  List<String> getCacheScopes(SharedPreferences prefs) {
    final scopes = <String>[];
    final username = prefs.getString(kUsername);

    if (username != null && username.isNotEmpty) {
      final usernameScope = 'user_$username';
      if (!scopes.contains(usernameScope)) {
        scopes.add(usernameScope);
      }
    }

    return scopes;
  }

  String buildScopedKey(String baseKey, String scope) {
    return '$baseKey$kScopedSeparator$scope';
  }

  Future<void> setScopedString(
    SharedPreferences prefs,
    String baseKey,
    String value,
  ) async {
    final scopes = getCacheScopes(prefs);
    if (scopes.isEmpty) {
      if (value.isEmpty) {
        await prefs.remove(baseKey);
      } else {
        await prefs.setString(baseKey, value);
      }
      return;
    }

    final primaryKey = buildScopedKey(baseKey, scopes.first);
    if (value.isEmpty) {
      await prefs.remove(primaryKey);
    } else {
      await prefs.setString(primaryKey, value);
    }
    await prefs.remove(baseKey);
  }

  Future<String?> getScopedString(
    SharedPreferences prefs,
    String baseKey,
  ) async {
    final scopes = getCacheScopes(prefs);
    for (final scope in scopes) {
      final value = prefs.getString(buildScopedKey(baseKey, scope));
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final legacyValue = prefs.getString(baseKey);
    if (scopes.isNotEmpty && legacyValue != null) {
      await prefs.remove(baseKey);
      return null;
    }
    return legacyValue;
  }

  Future<void> removeKeysWithPrefix(
    SharedPreferences prefs,
    String prefix,
  ) async {
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              key == prefix ||
              key.startsWith('${prefix}_') ||
              key.startsWith('$prefix:'),
        )
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
