import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/xg_activity.dart';
import '../models/xg_activity_record.dart';
import 'log_service.dart';
import 'xg_http.dart';
import '../constants/api_urls.dart';
import 'campus_access_service.dart';
import 'session_store.dart';
import 'sso_service.dart';
import 'xg_session_coordinator.dart';

/// 智慧学工活动服务
/// 负责处理活动列表、活动详情、报名和报名记录等业务逻辑
class XgActivityService {
  static const String campusUnavailableMessage = '校园网不可用，请连接校园网后重试';
  static final XgActivityService _instance = XgActivityService._internal();
  @visibleForTesting
  static const XgModule readModule = XgModule.activity;
  @visibleForTesting
  static const XgModule writeModule = XgModule.activity;
  static const XgModule pageReadModule = XgModule.activity;

  factory XgActivityService() {
    return _instance;
  }

  XgActivityService._internal();

  Exception _campusUnavailableError([Object? cause]) {
    return CampusServiceUnavailableException('智慧学工', cause: cause);
  }

  Future<bool>? _activitySessionRefreshTask;
  static const Duration _listCacheTtl = Duration(minutes: 15);

  String _requestSignature(Map<String, dynamic> requestParams) {
    final entries = requestParams.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return jsonEncode(Map<String, dynamic>.fromEntries(entries));
  }

  Future<({List<XgActivity> activities, int totalCount})?>
  loadAvailableActivitiesCache(Map<String, dynamic> requestParams) async {
    final raw = await SessionStore().getXgActivityListCache();
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (json['requestSignature'] != _requestSignature(requestParams)) {
        return null;
      }
      final cachedAt = DateTime.tryParse(json['cachedAt']?.toString() ?? '');
      if (cachedAt == null ||
          DateTime.now().toUtc().difference(cachedAt.toUtc()) > _listCacheTtl) {
        return null;
      }
      final rows = (json['activities'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => XgActivity.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final totalCount =
          int.tryParse(json['totalCount']?.toString() ?? '') ?? 0;
      return (activities: rows, totalCount: totalCount);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAvailableActivitiesCache(
    Map<String, dynamic> requestParams, {
    required List<XgActivity> activities,
    required int totalCount,
  }) async {
    await SessionStore().saveXgActivityListCache(
      jsonEncode({
        'requestSignature': _requestSignature(requestParams),
        'totalCount': totalCount,
        'activities': activities.map((item) => item.toJson()).toList(),
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<Response<T>> _postRead<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) {
    return XgHttp.instance.postFormWithModule(
      path,
      module: readModule,
      data: data,
      headers: headers,
    );
  }

  Future<Response<T>> _postWrite<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) {
    return XgHttp.instance.postFormWithModule(
      path,
      module: writeModule,
      data: data,
      headers: headers,
    );
  }

  /// 获取可报名活动列表
  /// [requestParams] 查询参数（页码、页大小、关键字、日期范围等）
  /// 返回可报名活动列表及总数量
  ///
  Future<({List<XgActivity> activities, int totalCount})>
  fetchAvailableActivities(Map<String, dynamic> requestParams) async {
    final stopwatch = Stopwatch()..start();
    // 确保网络层已初始化
    if (!XgHttp.instance.initialized) await XgHttp.instance.init();
    await XgSessionCoordinator.instance.ensureStudentReady(
      readModule,
      source: 'activity_list',
    );
    await LogService().logXgTrace(
      XgTraceLogEntry(
        phase: 'service',
        event: 'fetch_available_activities_started',
        module: 'xshdapp',
        page: 'xg_activity_service',
        requestKey: 'activity_list',
        result: 'started',
        extra: <String, dynamic>{'requestParams': requestParams},
      ),
    );

    const String apiPath =
        '/xsfw/sys/xshdapp/modules/studentActionApply/queryStudentApplyAction.do';

    Future<({List<XgActivity> activities, int totalCount})> doRequest() async {
      final response = await _postRead(
        apiPath,
        data: {'requestParamStr': jsonEncode(requestParams)},
        headers: {'Referer': '${ApiUrls.xgBaseUrl}$apiPath'},
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic data;
        try {
          data = response.data is String
              ? jsonDecode(response.data)
              : response.data;
        } catch (e) {
          // JSON 解析失败，可能是 HTML 或其他非 JSON 数据（例如会话刚刷新后的过渡页）
          await LogService().log('智慧学工', '活动列表响应解析失败: $e');
          throw Exception('活动列表解析失败');
        }

        if (data is Map<String, dynamic>) {
          final actionData = data['data']?['actionData'];
          final totalCountVal = data['data']?['totalCount'];

          int totalCount = 0;
          if (totalCountVal is int) {
            totalCount = totalCountVal;
          } else if (totalCountVal is String) {
            totalCount = int.tryParse(totalCountVal) ?? 0;
          }

          // 防御性编程：如果 actionData 为空，视为空列表并记录日志
          if (actionData == null) {
            await LogService().log(
              '智慧学工',
              '获取活动列表: 数据为空 (actionData is null)，返回空列表',
            );
            return (activities: <XgActivity>[], totalCount: totalCount);
          }

          if (actionData is List) {
            final list = actionData.map((e) => XgActivity.fromJson(e)).toList();
            await saveAvailableActivitiesCache(
              requestParams,
              activities: list,
              totalCount: totalCount,
            );
            await LogService().logXgTrace(
              XgTraceLogEntry(
                phase: 'service',
                event: 'fetch_available_activities_finished',
                module: 'xshdapp',
                page: 'xg_activity_service',
                requestKey: 'activity_list',
                elapsedMs: stopwatch.elapsedMilliseconds,
                result: 'ok',
                extra: <String, dynamic>{
                  'count': list.length,
                  'totalCount': totalCount,
                },
              ),
            );
            return (activities: list, totalCount: totalCount);
          }
        }

        // 结构不符合预期
        final dataType = data['data']?['actionData']?.runtimeType;
        await LogService().log(
          '智慧学工',
          '活动列表结构异常: actionData type is $dataType',
        );
        throw Exception('活动列表结构异常');
      }

      throw Exception('活动列表请求失败，状态码: ${response.statusCode}');
    }

    try {
      return await doRequest();
    } catch (e) {
      await LogService().log('智慧学工', '获取可报名活动列表失败: $e');
      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'service',
          event: 'fetch_available_activities_failed',
          module: 'xshdapp',
          page: 'xg_activity_service',
          requestKey: 'activity_list',
          elapsedMs: stopwatch.elapsedMilliseconds,
          result: 'error',
          reason: e.runtimeType.toString(),
          extra: <String, dynamic>{'message': e.toString()},
        ),
      );
      if (CampusAccessService.isCampusNetworkUnavailableError(e) ||
          e is CampusServiceUnavailableException) {
        throw _campusUnavailableError(e);
      }
      rethrow;
    }
  }

  /// 获取我的活动记录
  /// [page] 页码，从1开始
  /// [pageSize] 每页数量
  Future<({List<XgActivityRecord> records, int total})> fetchMyActivities({
    int page = 1,
    int pageSize = 10,
    bool allowCrossUserFix = true,
  }) async {
    // 确保网络层已初始化
    if (!XgHttp.instance.initialized) await XgHttp.instance.init();
    await XgSessionCoordinator.instance.ensureStudentReady(
      readModule,
      source: 'my_activities',
    );

    const String apiUrl = '/xsfw/sys/xshdapp/modules/hdll/hdsqjlbg.do';

    Future<({List<XgActivityRecord> records, int total})> doRequest() async {
      final response = await _postRead(
        apiUrl,
        data: {'pageSize': pageSize, 'pageNumber': page},
        headers: {'Referer': '${ApiUrls.xgBaseUrl}$apiUrl'},
      );

      if (response.data == null) {
        throw Exception('活动记录响应为空');
      }

      final raw = response.data;
      if (raw is String && raw.trim().isEmpty) {
        throw Exception('活动记录响应为空');
      }

      dynamic data;
      try {
        data = raw is String ? jsonDecode(raw) : raw;
      } catch (e) {
        throw Exception('活动记录解析失败: $e');
      }

      final hdsqjlbg = data['datas']?['hdsqjlbg'];
      if (hdsqjlbg != null) {
        final rows = hdsqjlbg['rows'] as List?;
        final total = hdsqjlbg['totalSize'] as int? ?? 0;
        if (rows != null) {
          final records = rows
              .map((e) => XgActivityRecord.fromJson(e))
              .toList();

          if (records.isNotEmpty) {
            final store = SessionStore();
            final currentUsername = await store.getUsername();
            if (currentUsername != null && currentUsername.isNotEmpty) {
              final mismatched = records.where(
                (r) => r.studentId.isNotEmpty && r.studentId != currentUsername,
              );

              if (mismatched.isNotEmpty) {
                if (allowCrossUserFix) {
                  await LogService().log(
                    '智慧学工',
                    '检测到活动记录存在学号与当前账号($currentUsername)不一致的数据，准备强制刷新会话后重试',
                  );

                  final refreshed =
                      await _refreshActivitySessionForCurrentUser();
                  if (refreshed) {
                    return await fetchMyActivities(
                      page: page,
                      pageSize: pageSize,
                      allowCrossUserFix: false,
                    );
                  }

                  await LogService().log(
                    '智慧学工',
                    '活动模块会话刷新失败或未获取到有效WEU，已停止重试并丢弃当前数据',
                  );
                } else {
                  await LogService().log(
                    '智慧学工',
                    '二次请求后活动记录学号仍与当前账号($currentUsername)不一致，已放弃展示该数据',
                  );
                }

                return (records: <XgActivityRecord>[], total: 0);
              }
            }
          }

          return (records: records, total: total);
        }
      }
      return (records: <XgActivityRecord>[], total: 0);
    }

    try {
      return await doRequest();
    } catch (e) {
      await LogService().log('智慧学工', '获取活动列表失败: $e');
      if (CampusAccessService.isCampusNetworkUnavailableError(e) ||
          e is CampusServiceUnavailableException) {
        throw _campusUnavailableError(e);
      }
      rethrow;
    }
  }

  /// 获取活动详情数据
  /// [activityId] 活动ID (HDDM)
  /// 返回原始详情数据 Map，用于详情页展示
  Future<Map<String, dynamic>> fetchActivityDetail(String activityId) async {
    if (!XgHttp.instance.initialized) await XgHttp.instance.init();
    await XgSessionCoordinator.instance.ensureStudentReady(
      readModule,
      source: 'activity_detail',
    );

    const String apiPath =
        '/xsfw/sys/xshdapp/modules/studentActionApply/queryStudentActionInfo.do';

    try {
      final response = await _postRead(
        apiPath,
        data: {
          'requestParamStr': jsonEncode({'HDDM': activityId}),
        },
        headers: {'Referer': '${ApiUrls.xgBaseUrl}$apiPath'},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data;
        final detail = data['data'];
        if (detail is Map<String, dynamic>) {
          return detail;
        }
      }

      throw Exception('无法获取活动详情');
    } catch (e) {
      await LogService().log('活动详情', '获取详情失败: $e');
      rethrow;
    }
  }

  /// 执行报名操作
  /// [activityId] 活动ID
  /// [cycd] 参与程度代码
  /// [activityName] 活动名称，用于日志
  /// [roleName] 身份名称，用于日志
  /// [scene] 场景标识（列表页 / 详情页等），便于区分日志来源
  /// 返回 (是否成功, 提示信息)
  Future<({bool success, String message})> applyForActivity({
    required String activityId,
    required String cycd,
    String? activityName,
    String? roleName,
    String scene = '报名列表',
  }) async {
    if (!XgHttp.instance.initialized) await XgHttp.instance.init();
    await XgSessionCoordinator.instance.ensureStudentReady(
      writeModule,
      source: 'activity_apply',
    );

    const String apiPath =
        '/xsfw/sys/xshdapp/modules/studentActionApply/studentApplyJoinAction.do';

    try {
      final response = await _postWrite(
        apiPath,
        data: {
          'requestParamStr': jsonEncode({'CYCD': cycd, 'HDDM': activityId}),
        },
        headers: {'Referer': '${ApiUrls.xgBaseUrl}$apiPath'},
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final logName = activityName ?? activityId;
      final roleInfo = roleName != null ? ' (身份: $roleName)' : '';

      if (data['returnCode'] == '#E000000000000') {
        await LogService().log('智慧学工', '$scene报名成功: $logName$roleInfo');
        return (success: true, message: '报名成功');
      } else {
        final desc = (data['description'] ?? '报名失败').toString();
        await LogService().log(
          '智慧学工',
          '$scene报名失败: $desc, 活动: $logName$roleInfo',
        );
        return (success: false, message: desc);
      }
    } catch (e) {
      await LogService().log('智慧学工', '报名请求异常: $e');
      return (success: false, message: '请求失败: $e');
    }
  }

  Future<bool> _refreshActivitySessionForCurrentUser() async {
    final ongoing = _activitySessionRefreshTask;
    if (ongoing != null) {
      return ongoing;
    }

    final future = _doRefreshActivitySessionForCurrentUser();
    _activitySessionRefreshTask = future;

    try {
      return await future;
    } finally {
      if (identical(_activitySessionRefreshTask, future)) {
        _activitySessionRefreshTask = null;
      }
    }
  }

  Future<bool> _doRefreshActivitySessionForCurrentUser() async {
    try {
      await XgSessionCoordinator.instance.prepareStudentModule(
        readModule,
        forceRefresh: true,
        source: 'cross_user_fix',
      );
      await LogService().log('智慧学工', '已强制刷新活动模块智慧学工会话');
      return true;
    } catch (e) {
      await LogService().log('智慧学工', '强制刷新活动模块会话失败: $e');
      return false;
    }
  }
}
