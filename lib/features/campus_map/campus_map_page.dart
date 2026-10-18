import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/campus_map_models.dart';
import 'campus_map_service.dart';
import '../../services/native_location_service.dart';
import '../../ui/components/app_page_app_bar.dart';
import '../../ui/components/custom_toast.dart';

// ---- WGS-84 (GPS) → GCJ-02 (高德/国测局) 坐标转换 ----
// 参考 https://github.com/wandergis/coordTransform 的算法实现
// 不加此转换时，GPS 坐标叠加到高德瓦片会有 300~500 米偏移

const double _a = 6378245.0; // 长半轴
const double _ee = 0.00669342162296594323; // 第一偏心率平方

LatLng wgs84ToGcj02(double wgLat, double wgLng) {
  if (_outOfChina(wgLat, wgLng)) return LatLng(wgLat, wgLng);

  double dLat = _transformLat(wgLng - 105.0, wgLat - 35.0);
  double dLng = _transformLng(wgLng - 105.0, wgLat - 35.0);

  final radLat = wgLat / 180.0 * pi;
  double magic = sin(radLat);
  magic = 1 - _ee * magic * magic;
  final sqrtMagic = sqrt(magic);
  dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * pi);
  dLng = (dLng * 180.0) / ((_a / sqrtMagic) * cos(radLat) * pi);

  return LatLng(wgLat + dLat, wgLng + dLng);
}

LatLng gcj02ToWgs84(double gcjLat, double gcjLng) {
  if (_outOfChina(gcjLat, gcjLng)) return LatLng(gcjLat, gcjLng);

  final converted = wgs84ToGcj02(gcjLat, gcjLng);
  final dLat = converted.latitude - gcjLat;
  final dLng = converted.longitude - gcjLng;
  return LatLng(gcjLat - dLat, gcjLng - dLng);
}

bool _outOfChina(double lat, double lng) {
  return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
}

double _transformLat(double x, double y) {
  double ret =
      -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * sqrt(x.abs());
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
  ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0;
  return ret;
}

double _transformLng(double x, double y) {
  double ret =
      300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
  ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
  return ret;
}

/// 校园地图页面
class CampusMapPage extends StatefulWidget {
  final CampusMapService? service;
  final bool enableAutoLocate;
  final bool showTileLayer;
  final bool skipInitialLoad;
  final List<MapCategory> initialCategories;
  final List<CampusMarker> initialMarkers;

  const CampusMapPage({
    super.key,
    this.service,
    this.enableAutoLocate = true,
    this.showTileLayer = true,
    this.skipInitialLoad = false,
    this.initialCategories = const [],
    this.initialMarkers = const [],
  });

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  late final CampusMapService _service;

  static const _campusCenter = LatLng(22.8095, 113.3245);
  static const _defaultZoom = 15.5;

  List<MapCategory> _categories = [];
  List<CampusMarker> _markers = [];
  int _activeCategoryIndex = 0; // 0 = "全部"
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearchMode = false;
  bool _searching = false;
  LatLng? _userLocation;
  bool _isLocating = false;
  bool _useSatelliteMap = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CampusMapService();
    if (widget.skipInitialLoad) {
      _categories = List<MapCategory>.from(widget.initialCategories);
      _markers = List<CampusMarker>.from(widget.initialMarkers);
      _loading = false;
    } else {
      _loadData();
    }
    if (widget.enableAutoLocate) {
      _autoLocate();
    }
  }

  /// 原生定位：先网络定位（基站/WiFi，室内秒级），失败则 GPS
  /// 高德地图等国产 App 也是类似机制，直接使用 Android LocationManager

  Future<void> _loadData({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        _service.clearCache();
      }
      await _service.init();
      final categories = await _service.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
      _loadMarkers(0); // 默认加载"全部"
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMarkers(
    int categoryId, {
    bool animateToFirst = false,
  }) async {
    setState(() => _searching = true);
    try {
      final markers = categoryId == 0
          ? await _service.getAllMarkers()
          : await _service.getMarkers(categoryId);
      if (!mounted) return;
      setState(() {
        _markers = markers;
        _searching = false;
      });
      if (animateToFirst && markers.isNotEmpty) {
        _mapController.move(
          LatLng(markers.first.latitude, markers.first.longitude),
          16,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _onCategoryTap(int index) {
    if (_isSearchMode) return; // 搜索模式下分类不可用
    if (_activeCategoryIndex == index) return;
    setState(() {
      _activeCategoryIndex = index;
      _markers = [];
    });
    final id = index == 0 ? 0 : _categories[index - 1].id;
    _loadMarkers(id, animateToFirst: true);
  }

  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      _searchController.clear();
    });
    if (!_isSearchMode) {
      // 取消搜索，恢复当前分类
      final id = _activeCategoryIndex == 0
          ? 0
          : _categories[_activeCategoryIndex - 1].id;
      _loadMarkers(id);
    }
  }

  Future<void> _onSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await _service.search(keyword);
      if (!mounted) return;
      setState(() {
        _markers = results;
        _searching = false;
      });
      if (results.isNotEmpty) {
        _mapController.move(
          LatLng(results.first.latitude, results.first.longitude),
          _defaultZoom,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _onMarkerTap(CampusMarker marker) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _MarkerDetailSheet(
        marker: marker,
        onOpenMap: () => _openMarkerInMap(marker),
      ),
    );
  }

  Uri _buildSystemGeoUri(CampusMarker marker) {
    final destinationName = Uri.encodeComponent(marker.title);
    // 标注点坐标是 GCJ-02，geo: URI 按 RFC 5870 规范应使用 WGS-84
    final wgs84 = gcj02ToWgs84(marker.latitude, marker.longitude);
    // ★ 修复：坐标必须放在 geo: 前缀中，?q= 仅放名称作为标注
    //   旧格式 geo:0,0?q=lat,lng(name) 会让地图 App 把坐标当文本搜索
    return Uri.parse(
      'geo:${wgs84.latitude},${wgs84.longitude}?q=$destinationName',
    );
  }

  Future<void> _openMarkerInMap(CampusMarker marker) async {
    var launched = false;
    try {
      launched = await launchUrl(
        _buildSystemGeoUri(marker),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!launched && mounted) {
      CustomToast.error(context, message: '打开系统地图失败');
    }
  }

  /// 进入页面后自动定位
  /// 使用原生定位通道（直接调用 Android LocationManager），
  /// 高德地图也是类似机制——网络定位（基站/WiFi，室内秒级），失败则静默等待手动定位
  Future<void> _autoLocate() async {
    try {
      final hasPermission = await _ensureLocationPermission(showError: false);
      if (!hasPermission) return;
      final result = await NativeLocationService().getCurrentPosition();
      if (!mounted) return;
      final gcj02 = wgs84ToGcj02(result.latitude, result.longitude);
      _mapController.move(gcj02, 16);
      _userLocation = gcj02;
      if (mounted) setState(() {});
    } catch (_) {
      // 自动定位失败不阻塞用户，可通过左下角定位按钮手动定位
    }
  }

  /// 手动定位到当前位置
  Future<void> _locateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) return;
      final result = await NativeLocationService().getCurrentPosition();
      if (!mounted) return;
      final gcj02 = wgs84ToGcj02(result.latitude, result.longitude);
      _mapController.move(gcj02, 16);
      setState(() => _userLocation = gcj02);
    } on PlatformException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'PERMISSION_DENIED':
          _showLocationError('需要定位权限才能显示当前位置');
          break;
        case 'LOCATION_DISABLED':
          _showLocationError('手机定位服务未开启，请在系统设置中打开 GPS');
          break;
        default:
          _showLocationError('获取当前位置失败，请检查定位权限和 GPS 开关');
      }
    } catch (e) {
      if (mounted) {
        _showLocationError('获取当前位置失败，请检查定位权限和 GPS 开关');
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<bool> _ensureLocationPermission({bool showError = true}) async {
    var status = await Permission.location.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (showError && mounted) {
        _showLocationPermissionSettingsError();
      }
      return false;
    }

    status = await Permission.location.request();
    if (status.isGranted) return true;

    if (!showError || !mounted) {
      return false;
    }

    if (status.isPermanentlyDenied) {
      _showLocationPermissionSettingsError();
    } else {
      _showLocationError('需要授予定位权限后才能显示当前位置');
    }
    return false;
  }

  void _showLocationPermissionSettingsError() {
    CustomToast.show(
      context,
      message: '定位权限已被永久拒绝，请在系统设置中开启定位权限',
      icon: Icons.location_off_outlined,
      iconColor: const Color(0xFFFF6B6B),
      duration: const Duration(seconds: 5),
      actionLabel: '去设置',
      onAction: openAppSettings,
    );
  }

  /// 右上角图标+文字按钮（图层/更多）
  Widget _buildIconLabelButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF008B83)),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationError(String message) {
    CustomToast.error(context, message: message);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 根据屏幕像素密度选择高德瓦片分辨率
    // scale=1 → 256px 瓦片，在 2x/3x 屏幕上会模糊
    // scale=2 → 512px，适合大多数设备；scale=3 → 768px 适合超高密度屏
    final tileScale = MediaQuery.devicePixelRatioOf(context) >= 3 ? '3' : '2';

    return Scaffold(
      appBar: AppPageAppBar(
        title: '校园地图',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 22),
            color: const Color(0xFF008b83),
            tooltip: '刷新标注点',
            onPressed: () {
              _loadData(forceRefresh: true);
              CustomToast.show(
                context,
                message: '正在刷新...',
                icon: Icons.refresh_rounded,
                duration: const Duration(seconds: 1),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTopRow(),
                Expanded(child: _buildMap(tileScale)),
              ],
            ),
    );
  }

  /// 搜索按钮 + 分类标签同在一行
  Widget _buildTopRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // 搜索按钮在分类左侧
          _buildSearchButton(),
          const SizedBox(width: 8),
          // 分类列表 或 搜索输入框
          Expanded(child: _buildCategoryBar()),
        ],
      ),
    );
  }

  Widget _buildSearchButton() {
    return GestureDetector(
      onTap: _toggleSearch,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _isSearchMode
              ? const Color(0xFF008b83)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          _isSearchMode ? Icons.close : Icons.search,
          size: 18,
          color: _isSearchMode ? Colors.white : const Color(0xFF666666),
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    if (_isSearchMode) {
      // 搜索模式：分类栏变成搜索输入框
      return SizedBox(
        height: 36,
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: '搜索地点...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF008b83)),
            ),
          ),
          onSubmitted: _onSearch,
        ),
      );
    }

    // 分类模式："全部" + 全部分类
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTab('全部', 0),
          for (var i = 0; i < _categories.length; i++)
            _buildTab(_categories[i].name, i + 1),
        ],
      ),
    );
  }

  Widget _buildTab(String name, int index) {
    final isActive = index == _activeCategoryIndex;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => _onCategoryTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF008b83) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? Colors.white : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(String tileScale) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _campusCenter,
            initialZoom: _defaultZoom,
            minZoom: 14,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags:
                  InteractiveFlag.drag |
                  InteractiveFlag.pinchMove |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.flingAnimation,
            ),
          ),
          children: [
            if (widget.showTileLayer)
              TileLayer(
                key: ValueKey('tile_$_useSatelliteMap'),
                urlTemplate: _useSatelliteMap
                    ? 'https://webst0{s}.is.autonavi.com/appmaptile'
                          '?lang=zh_cn&size=1&scale=$tileScale&style=6'
                          '&x={x}&y={y}&z={z}'
                    : 'https://webrd0{s}.is.autonavi.com/appmaptile'
                          '?lang=zh_cn&size=1&scale=$tileScale&style=8'
                          '&x={x}&y={y}&z={z}',
                subdomains: const ['1', '2', '3', '4'],
                maxZoom: 18,
                userAgentPackageName: 'io.github.xshunai.campusassistant',
              ),
            if (_userLocation != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userLocation!,
                    radius: 9,
                    color: const Color(0xFF2196F3),
                    borderColor: Colors.white,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
        if (_searching)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 6),
                    Text('加载中...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        // 仓库未内置标注数据时给出提示，避免误以为地图加载失败。
        if (!_loading && !_searching && _markers.isEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 70,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  '暂未配置校园标注数据',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
            ),
          ),
        // 定位按钮（右下角）
        Positioned(
          right: 14,
          bottom: 10,
          child: FloatingActionButton.small(
            heroTag: 'locate_me',
            backgroundColor: Colors.white,
            onPressed: _locateMe,
            child: _isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.my_location_outlined,
                    color: Color(0xFF008b83),
                  ),
          ),
        ),
        // 右上角图层切换按钮
        Positioned(
          right: 14,
          top: 14,
          child: _buildIconLabelButton(
            key: const Key('campus_map_layer_switch'),
            icon: _useSatelliteMap ? Icons.map : Icons.satellite_alt_outlined,
            label: '图层',
            onTap: () => setState(() => _useSatelliteMap = !_useSatelliteMap),
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // 校园标注点
    for (final m in _markers) {
      // 本地标注点统一使用主题绿色
      const markerColor = Color(0xFF008b83);
      markers.add(
        Marker(
          point: LatLng(m.latitude, m.longitude),
          width: 90,
          height: 52,
          child: GestureDetector(
            onTap: () => _onMarkerTap(m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: markerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    m.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Icon(Icons.location_on, color: markerColor, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }
}

/// 标注点详情底部弹窗
class _MarkerDetailSheet extends StatelessWidget {
  final CampusMarker marker;
  final VoidCallback onOpenMap;

  const _MarkerDetailSheet({required this.marker, required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            marker.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '坐标: ${marker.latitude.toStringAsFixed(5)}, ${marker.longitude.toStringAsFixed(5)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onOpenMap();
              },
              icon: const Icon(Icons.navigation_outlined, size: 18),
              label: const Text('导航前往到此处'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008b83),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
