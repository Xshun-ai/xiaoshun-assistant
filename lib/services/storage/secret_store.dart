import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 敏感数据存储抽象。
///
/// 生产环境使用系统安全存储；测试或插件未注册时退化为进程内存储，
/// 避免因为平台通道缺失导致业务直接崩溃。
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Map<String, String> _fallback = {};

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return _fallback[key];
    } on PlatformException {
      return _fallback[key];
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      _fallback[key] = value;
    } on PlatformException {
      _fallback[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      _fallback.remove(key);
    } on PlatformException {
      _fallback.remove(key);
    }
  }
}

class SecretStoreBinding {
  static SecretStore? _override;
  static FlutterSecureSecretStore? _production;

  static SecretStore get instance =>
      _override ?? (_production ??= FlutterSecureSecretStore());

  static void installForTest(SecretStore store) {
    _override = store;
  }
}
