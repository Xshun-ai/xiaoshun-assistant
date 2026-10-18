import 'dart:convert';

import 'package:flutter/services.dart';

import 'models/campus_map_models.dart';

/// 校园地图服务 - 提供本地离线校园地图分类和标注点数据
///
/// 数据源为 assets/json/campus_markers.json。
/// 仓库默认不内置具体标注点，使用方可自行填写 `markers` 数组。
class CampusMapService {
  static final CampusMapService _instance = CampusMapService._internal();
  factory CampusMapService() => _instance;
  CampusMapService._internal();
  static const String _localAssetPath = 'assets/json/campus_markers.json';

  /// 清空本地缓存，下次请求将重新读取资源文件
  void clearCache() {
    _cachedCategories = null;
    _cachedMarkers = null;
  }

  // ---- 公共接口 ----

  /// 初始化（预加载本地标记到内存）
  Future<void> init() async {
    await _ensureLocalDataLoaded();
  }

  /// 获取分类列表（标签Tab）
  Future<List<MapCategory>> getCategories() async {
    await _ensureLocalDataLoaded();
    return _cachedCategories ?? _defaultCategories();
  }

  /// 获取全部标注点（用于「全部」分类标签）
  Future<List<CampusMarker>> getAllMarkers() async {
    await _ensureLocalDataLoaded();
    return _cachedMarkers ?? const [];
  }

  /// 获取指定分类的标注点
  Future<List<CampusMarker>> getMarkers(int categoryId) async {
    await _ensureLocalDataLoaded();
    return _localMarkersByCategory(categoryId);
  }

  /// 搜索地点（本地名称模糊匹配）
  Future<List<CampusMarker>> search(String keyword) async {
    await _ensureLocalDataLoaded();
    return _searchLocal(keyword);
  }

  // ---- 本地数据 ----

  List<MapCategory>? _cachedCategories;
  List<CampusMarker>? _cachedMarkers;

  Future<void> _ensureLocalDataLoaded() async {
    if (_cachedCategories != null && _cachedMarkers != null) {
      return;
    }

    try {
      final raw = await rootBundle.loadString(_localAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cachedCategories =
            (decoded['categories'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map(
                  (item) =>
                      MapCategory.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList();
        _cachedMarkers = (decoded['markers'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => CampusMarker.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        if (_cachedCategories!.isNotEmpty) {
          return;
        }
      }
    } catch (_) {}

    _cachedCategories ??= _defaultCategories();
    _cachedMarkers ??= const [];
  }

  List<MapCategory> _defaultCategories() {
    return const [
      MapCategory(id: 1, name: '教学楼', icon: 'school'),
      MapCategory(id: 7, name: '实训楼', icon: 'build'),
      MapCategory(id: 9, name: '报告厅', icon: 'mic'),
      MapCategory(id: 6, name: '礼堂/体育馆', icon: 'stadium'),
      MapCategory(id: 2, name: '运动场', icon: 'fitness_center'),
      MapCategory(id: 3, name: '食堂', icon: 'restaurant'),
      MapCategory(id: 4, name: '宿舍', icon: 'hotel'),
      MapCategory(id: 5, name: '校门', icon: 'door_front'),
      MapCategory(id: 8, name: '其他', icon: 'place'),
    ];
  }

  List<CampusMarker> _localMarkersByCategory(int lid) {
    final all = _cachedMarkers ?? const [];
    return all.where((m) => m.lid == lid).toList();
  }

  List<CampusMarker> _searchLocal(String keyword) {
    final lower = keyword.toLowerCase();
    final cache = _cachedMarkers ?? [];
    return cache.where((m) => m.title.toLowerCase().contains(lower)).toList();
  }
}
