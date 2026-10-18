import 'package:flutter/material.dart';

import '../services/campus_access_service.dart';

/// 可加载状态数据类
///
/// 封装异步数据加载过程中的三种状态：加载中、成功、失败
class LoadableData<T> {
  /// 是否正在加载
  final bool loading;

  /// 数据内容
  final T? data;

  /// 错误信息
  final String error;

  const LoadableData({this.loading = false, this.data, this.error = ''});

  /// 创建加载中状态
  factory LoadableData.loading({T? previousData}) {
    return LoadableData<T>(loading: true, data: previousData, error: '');
  }

  /// 创建成功状态
  factory LoadableData.success(T data) {
    return LoadableData<T>(loading: false, data: data, error: '');
  }

  /// 创建失败状态
  factory LoadableData.error(String message, {T? previousData}) {
    return LoadableData<T>(loading: false, data: previousData, error: message);
  }

  /// 是否有数据
  bool get hasData => data != null;

  /// 是否有错误
  bool get hasError => error.isNotEmpty;

  /// 复制并更新状态
  LoadableData<T> copyWith({bool? loading, T? data, String? error}) {
    return LoadableData<T>(
      loading: loading ?? this.loading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

/// 可加载状态 Mixin
///
/// 为 StatefulWidget 提供统一的数据加载和状态管理能力
///
/// 使用方法：
/// ```dart
/// class _MyPageState extends State<MyPage> with LoadableStateMixin {
///   @override
///   void initState() {
///     super.initState();
///     loadData('myData', () async {
///       return await fetchMyData();
///     });
///   }
///
///   Widget build(BuildContext context) {
///     return buildLoadable(
///       'myData',
///       builder: (data) => Text(data),
///       emptyMessage: '暂无数据',
///     );
///   }
/// }
/// ```
mixin LoadableStateMixin<T extends StatefulWidget> on State<T> {
  /// 存储所有可加载数据的Map
  final Map<String, LoadableData<dynamic>> _loadables = {};

  /// 获取指定key的可加载数据
  LoadableData<D> getLoadable<D>(String key) {
    return _loadables[key] as LoadableData<D>? ?? LoadableData<D>();
  }

  /// 更新指定key的可加载数据状态
  void updateLoadable<D>(String key, LoadableData<D> loadable) {
    if (mounted) {
      setState(() {
        _loadables[key] = loadable;
      });
    }
  }

  /// 执行异步加载操作
  ///
  /// [key] 数据标识符
  /// [loader] 异步加载函数
  /// [cacheLoader] 可选的缓存加载函数（先加载缓存，再刷新）
  /// [onSuccess] 加载成功回调
  /// [onError] 加载失败回调
  Future<void> loadData<D>({
    required String key,
    required Future<D> Function() loader,
    Future<D?> Function()? cacheLoader,
    void Function(D data)? onSuccess,
    Future<void> Function(String error)? onError,
  }) async {
    final previousData = getLoadable<D>(key).data;
    if (mounted) {
      setState(() {
        _loadables[key] = LoadableData<D>.loading(previousData: previousData);
      });
    }

    // 如果提供了缓存加载器，先加载缓存
    D? cachedData;
    bool hasCachedData = false;
    if (cacheLoader != null) {
      try {
        cachedData = await cacheLoader();
        if (cachedData != null && mounted) {
          hasCachedData = true;
          setState(() {
            _loadables[key] = LoadableData<D>.success(cachedData as D);
          });
          debugPrint('[$key] 缓存加载成功，立即显示缓存内容');
        }
      } catch (e) {
        debugPrint('缓存加载失败 [$key]: $e');
      }
    }

    try {
      // 执行异步加载（后台刷新）
      final data = await loader();

      if (mounted) {
        setState(() {
          _loadables[key] = LoadableData<D>.success(data);
        });
        debugPrint('[$key] 网络数据加载成功，已更新');
      }

      // 触发成功回调
      if (onSuccess != null && mounted) {
        onSuccess(data);
      }
    } catch (e) {
      final errorMessage = e.toString();
      debugPrint('数据加载失败 [$key]: $errorMessage');

      if (mounted) {
        // 如果有缓存数据，保留缓存不显示错误
        if (hasCachedData) {
          debugPrint('[$key] 网络请求失败，但保留缓存数据供用户使用');
          // 保持当前缓存数据不变，不更新为error状态
        } else {
          // 没有缓存才显示错误
          setState(() {
            _loadables[key] = LoadableData<D>.error(errorMessage);
          });
        }
      }

      // 触发失败回调
      if (onError != null && mounted) {
        await onError(errorMessage);
      }
    }
  }

  /// 构建可加载数据的UI组件
  ///
  /// [key] 数据标识符
  /// [builder] 数据渲染构建器
  /// [loadingBuilder] 自定义加载中UI（可选）
  /// [skeletonBuilder] 自定义骨架屏UI（可选，优先级高于loadingBuilder）
  /// [errorBuilder] 自定义错误UI（可选）
  /// [emptyMessage] 空数据提示文本
  /// [errorMessage] 错误提示文本前缀
  Widget buildLoadable<D>({
    required String key,
    required Widget Function(D data) builder,
    Widget Function()? loadingBuilder,
    Widget Function()? skeletonBuilder,
    Widget Function(String error)? errorBuilder,
    Widget Function()? emptyBuilder,
    String emptyMessage = '暂无数据',
    String? errorMessage,
  }) {
    final loadable = getLoadable<D>(key);

    // 加载中状态（且无缓存数据）
    if (loadable.loading && !loadable.hasData) {
      // 优先使用骨架屏，其次使用自定义loading，最后使用默认loading
      if (skeletonBuilder != null) {
        return skeletonBuilder.call();
      }
      return loadingBuilder?.call() ??
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
    }

    // 有数据 - 优先显示数据（即使正在刷新）
    if (loadable.hasData) {
      final data = loadable.data as D;

      // 特殊处理：如果数据是空列表，显示空状态提示
      if (data is List && (data as List).isEmpty) {
        return emptyBuilder?.call() ??
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  emptyMessage,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            );
      }

      return builder(data);
    }

    // 错误状态
    if (loadable.hasError) {
      final errorText = errorMessage ?? loadable.error;
      if (errorBuilder != null) {
        return errorBuilder.call(errorText);
      }
      final displayText =
          errorMessage ??
          CampusAccessService.toUserFacingErrorMessage(
            loadable.error,
            fallback: '获取失败，请稍后重试',
          );
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            displayText,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
      );
    }

    // 空数据状态
    return emptyBuilder?.call() ??
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        );
  }
}
