package io.github.xshunai.campusassistant

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 原生定位通道 - 直接使用 Android LocationManager（无需 Google Play Services）
 *
 * 高德地图能定位的根本原因是使用自研 SDK 直接调用 LocationManager + 自有 WiFi 数据库。
 * 而 geolocator 插件依赖 Google Play Services (FusedLocationProvider)，国产手机通常无此服务。
 *
 * 本通道绕开 Google Play Services，直接使用 Android 原生定位 API：
 * 1. NETWORK_PROVIDER — 基于基站/WiFi，室内可用，<5s
 * 2. GPS_PROVIDER — 室外高精度，<30s
 */
class LocationPlugin(private val context: Context) {

    companion object {
        private const val CHANNEL = "io.github.xshunai.campusassistant/location"
        private const val TAG = "LocationPlugin"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            val plugin = LocationPlugin(context)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentPosition" -> plugin.getCurrentPosition(result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    private val locationManager: LocationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    private fun getCurrentPosition(result: MethodChannel.Result) {
        // 检查定位权限
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "位置权限被拒绝", null)
            return
        }

        // 检查定位开关
        if (!locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) &&
            !locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
        ) {
            result.error("LOCATION_DISABLED", "手机定位服务未开启", null)
            return
        }

        // 先用网络定位（快速，室内可用）
        val networkProvider = locationManager.getProvider(LocationManager.NETWORK_PROVIDER)
        if (networkProvider != null && locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            try {
                val lastKnown = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                if (lastKnown != null && System.currentTimeMillis() - lastKnown.time < 60000) {
                    // 1分钟内的缓存仍然有效
                    result.success(mapOf(
                        "latitude" to lastKnown.latitude,
                        "longitude" to lastKnown.longitude,
                        "accuracy" to "network"
                    ))
                    return
                }

                // 请求一次网络定位更新
                locationManager.requestSingleUpdate(
                    LocationManager.NETWORK_PROVIDER,
                    object : LocationListener {
                        override fun onLocationChanged(location: Location) {
                            locationManager.removeUpdates(this)
                            result.success(mapOf(
                                "latitude" to location.latitude,
                                "longitude" to location.longitude,
                                "accuracy" to "network"
                            ))
                        }

                        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                        override fun onProviderEnabled(provider: String) {}
                        override fun onProviderDisabled(provider: String) {}
                    },
                    Looper.getMainLooper()
                )
                return
            } catch (e: Exception) {
                // 网络定位失败，尝试GPS
            }
        }

        // 网络定位不可用，尝试 GPS 定位
        if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            try {
                locationManager.requestSingleUpdate(
                    LocationManager.GPS_PROVIDER,
                    object : LocationListener {
                        override fun onLocationChanged(location: Location) {
                            locationManager.removeUpdates(this)
                            result.success(mapOf(
                                "latitude" to location.latitude,
                                "longitude" to location.longitude,
                                "accuracy" to "gps"
                            ))
                        }

                        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                        override fun onProviderEnabled(provider: String) {}
                        override fun onProviderDisabled(provider: String) {}
                    },
                    Looper.getMainLooper()
                )
            } catch (e: Exception) {
                result.error("LOCATION_FAILED", "获取位置失败: ${e.message}", null)
            }
        } else {
            result.error("LOCATION_FAILED", "没有可用的定位方式（请开启网络定位或GPS）", null)
        }
    }
}
