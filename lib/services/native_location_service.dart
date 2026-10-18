import 'package:flutter/services.dart';

/// 原生定位服务
///
/// 通过 MethodChannel 调用 Android 原生 LocationManager（不依赖 Google Play Services），
/// 替代 geolocator 插件。高德地图等国产 App 也是类似机制定位的。
///
/// 定位策略（与高德地图一致）：
/// 1. NETWORK_PROVIDER — 基站/WiFi 定位，室内可用，通常<5s
/// 2. GPS_PROVIDER — 室外高精度定位
class NativeLocationService {
  static const _channel = MethodChannel(
    'io.github.xshunai.campusassistant/location',
  );

  static final NativeLocationService _instance =
      NativeLocationService._internal();
  factory NativeLocationService() => _instance;
  NativeLocationService._internal();

  /// 获取当前位置
  ///
  /// 返回 [NativeLocationResult] 包含经纬度和定位方式。
  /// 抛出 [PlatformException] 包含具体错误类型：
  /// - PERMISSION_DENIED — 定位权限被拒绝
  /// - LOCATION_DISABLED — 手机定位开关未开启
  /// - LOCATION_FAILED — 定位失败
  Future<NativeLocationResult> getCurrentPosition() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCurrentPosition',
      );
      if (result == null) {
        throw PlatformException(code: 'LOCATION_FAILED', message: '定位返回空');
      }
      return NativeLocationResult(
        latitude: (result['latitude'] as num).toDouble(),
        longitude: (result['longitude'] as num).toDouble(),
        accuracy: result['accuracy'] as String? ?? 'unknown',
      );
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(code: 'LOCATION_FAILED', message: '定位失败: $e');
    }
  }
}

/// 原生定位结果
class NativeLocationResult {
  final double latitude;
  final double longitude;
  final String accuracy; // 'network' 或 'gps'

  const NativeLocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy = 'unknown',
  });
}
