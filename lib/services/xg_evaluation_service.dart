import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_urls.dart';
import '../models/xg_evaluation_score.dart';
import '../models/xg_evaluation_semester.dart';
import 'campus_access_service.dart';
import 'log_service.dart';
import 'session_store.dart';
import 'sso_service.dart';
import 'xg_http.dart';
import 'xg_session_coordinator.dart';

/// 综合评测服务。
///
/// 提供学期列表、综测总分和排名查询。
class XgEvaluationService {
  static const String campusUnavailableMessage = '校园网不可用，请连接校园网后重试';

  @visibleForTesting
  static const XgModule readModule = XgModule.evaluation;

  static bool shouldAbortAfterScoreError(Object error) {
    return error is CampusServiceUnavailableException ||
        CampusAccessService.isCampusNetworkUnavailableError(error);
  }

  XgEvaluationService();

  @visibleForTesting
  static bool isEmptyScoreResponse(dynamic response) {
    if (response is! Map || response['code']?.toString() != '0') {
      return false;
    }
    final datas = response['datas'];
    if (datas is! Map) return false;
    final scoreData = datas['cpjgcxbgdz'];
    if (scoreData is! Map) return false;
    final rows = scoreData['rows'];
    return rows is List && rows.isEmpty;
  }

  String _summarizeResponse(dynamic data) {
    final raw = data?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (raw.isEmpty) {
      return '空响应';
    }

    final lower = raw.toLowerCase();
    if (lower.contains('<!doctype html') || lower.contains('<html')) {
      return 'HTML页面响应';
    }

    if (raw.length <= 120) {
      return raw;
    }

    return '${raw.substring(0, 120)}...';
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

  Future<void> saveOverviewCache({
    required List<XgEvaluationSemester> semesters,
    required XgEvaluationSemester? selectedSemester,
    required XgEvaluationScore? score,
  }) async {
    await SessionStore().saveXgEvaluationOverviewCache(
      jsonEncode({
        'semesters': semesters.map((item) => item.toJson()).toList(),
        'selectedSemester': selectedSemester?.toJson(),
        'score': score?.toJson(),
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  /// 获取可用学年学期列表。
  Future<List<XgEvaluationSemester>> getSemesters() async {
    final stopwatch = Stopwatch()..start();
    if (!XgHttp.instance.initialized) await XgHttp.instance.init();
    await XgSessionCoordinator.instance.ensureStudentReady(
      readModule,
      source: 'evaluation_semesters',
    );
    await LogService().logXgTrace(
      const XgTraceLogEntry(
        phase: 'service',
        event: 'get_semesters_started',
        module: 'zhcptybbapp',
        page: 'xg_evaluation_service',
        requestKey: 'evaluation_semesters',
        result: 'started',
      ),
    );

    const String path =
        '/xsfw/sys/zhcptybbapp/modules/evaluationResultController/getAvailableXnXq.do';

    Future<List<XgEvaluationSemester>> doRequest() async {
      final response = await _postRead(
        path,
        headers: {'Referer': '${ApiUrls.xgBaseUrl}$path', 'Accept': '*/*'},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception(
          '学期列表请求失败，状态码: ${response.statusCode}，响应: ${_summarizeResponse(response.data)}',
        );
      }

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          throw Exception('学期列表解析失败: $e');
        }
      }

      if (data is Map && data['data'] is List) {
        final list = (data['data'] as List)
            .map((e) => XgEvaluationSemester.fromJson(e))
            .toList();
        await LogService().logXgTrace(
          XgTraceLogEntry(
            phase: 'service',
            event: 'get_semesters_finished',
            module: 'zhcptybbapp',
            page: 'xg_evaluation_service',
            requestKey: 'evaluation_semesters',
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: 'ok',
            extra: <String, dynamic>{'count': list.length},
          ),
        );
        return list;
      }

      throw Exception('学期列表结构异常: ${_summarizeResponse(response.data)}');
    }

    try {
      return await doRequest();
    } catch (e) {
      if (CampusAccessService.isCampusNetworkUnavailableError(e) ||
          e is CampusServiceUnavailableException) {
        rethrow;
      }
      await LogService().log('综测', '获取综测学期列表失败: $e');
      return [];
    }
  }

  /// 获取批次代码 (PCDM)。
  Future<String?> _getPcdm(String cpxn, String cpxq) async {
    if (!XgHttp.instance.initialized) await XgHttp.instance.init();

    final cpxnInt = int.tryParse(cpxn) ?? 0;
    final cpxqInt = int.tryParse(cpxq) ?? 0;
    final dataMap = {'CPXN': cpxnInt, 'CPXQ': cpxqInt};

    const String path =
        '/xsfw/sys/zhcptybbapp/zhcpstatistics/getPcInfoByXnXq.do';

    Future<String?> doRequest() async {
      final response = await _postRead(
        path,
        data: {'data': jsonEncode(dataMap)},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception(
          'PCDM请求失败，状态码: ${response.statusCode}，响应: ${_summarizeResponse(response.data)}',
        );
      }

      dynamic resData = response.data;
      if (resData is String) {
        try {
          resData = jsonDecode(resData);
        } catch (e) {
          throw Exception('PCDM解析失败: $e');
        }
      }
      if (resData['code'] == '0' &&
          resData['data'] != null &&
          resData['data']['PC_ARRAY'] is List) {
        final list = resData['data']['PC_ARRAY'] as List;
        if (list.isNotEmpty) {
          return list.first['PCDM']?.toString();
        }
      }
      throw Exception('PCDM结构异常: ${_summarizeResponse(response.data)}');
    }

    try {
      return await doRequest();
    } catch (e) {
      if (CampusAccessService.isCampusNetworkUnavailableError(e) ||
          e is CampusServiceUnavailableException) {
        rethrow;
      }
      await LogService().log('综测', '获取PCDM失败: $e');
      return null;
    }
  }

  /// 获取综测总分和排名。
  Future<XgEvaluationScore?> getScore(XgEvaluationSemester semester) async {
    final stopwatch = Stopwatch()..start();
    if (!XgHttp.instance.initialized) await XgHttp.instance.init();
    await XgSessionCoordinator.instance.ensureStudentReady(
      readModule,
      source: 'evaluation_score',
    );
    await LogService().logXgTrace(
      XgTraceLogEntry(
        phase: 'service',
        event: 'get_score_started',
        module: 'zhcptybbapp',
        page: 'xg_evaluation_service',
        requestKey: 'evaluation_score',
        result: 'started',
        extra: <String, dynamic>{'semester': semester.displayName},
      ),
    );

    String? pcdm = semester.pcdm;
    if (pcdm == null || pcdm.isEmpty) {
      pcdm = await _getPcdm(semester.cpxn, semester.cpxq);
    }
    if (pcdm == null || pcdm.isEmpty) {
      await LogService().log('综测', '缺少批次代码(PCDM)，无法查询成绩');
      return null;
    }

    final cpxnVal = int.tryParse(semester.cpxn) ?? semester.cpxn;
    final cpxqVal = int.tryParse(semester.cpxq) ?? semester.cpxq;
    final querySetting = [
      {'name': 'CPXN', 'value': cpxnVal, 'linkOpt': 'AND', 'builder': 'equal'},
      {'name': 'CPXQ', 'value': cpxqVal, 'linkOpt': 'AND', 'builder': 'equal'},
      {'name': 'PCDM', 'value': pcdm, 'linkOpt': 'AND', 'builder': 'equal'},
    ];

    final data = {
      'CPXN': semester.cpxn,
      'CPXQ': semester.cpxq,
      'PCDM': pcdm,
      'querySetting': jsonEncode(querySetting),
      'pageSize': 10,
      'pageNumber': 1,
    };

    const String path = '/xsfw/sys/zhcptybbapp/modules/cpjgcx/cpjgcxbgdz.do';

    Future<XgEvaluationScore?> doRequest({
      bool allowCrossUserFix = true,
    }) async {
      final response = await _postRead(
        path,
        data: data,
        headers: {'Referer': '${ApiUrls.xgBaseUrl}$path', 'Accept': '*/*'},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception(
          '综测成绩请求失败，状态码: ${response.statusCode}，响应: ${_summarizeResponse(response.data)}',
        );
      }

      dynamic resData = response.data;
      if (resData is String) {
        try {
          resData = jsonDecode(resData);
        } catch (e) {
          throw Exception('综测成绩解析失败: $e');
        }
      }
      if (isEmptyScoreResponse(resData)) {
        await LogService().log('综测', '当前学期暂无综测成绩');
        return null;
      }
      if (resData['code']?.toString() == '0' &&
          resData['datas'] != null &&
          resData['datas']['cpjgcxbgdz'] != null &&
          resData['datas']['cpjgcxbgdz']['rows'] is List) {
        final rows = resData['datas']['cpjgcxbgdz']['rows'] as List;
        if (rows.isNotEmpty) {
          final score = XgEvaluationScore.fromJson(rows.first);

          if (score.xsbh.isNotEmpty) {
            final store = SessionStore();
            final currentUsername = await store.getUsername();
            if (currentUsername != null &&
                currentUsername.isNotEmpty &&
                score.xsbh != currentUsername) {
              if (allowCrossUserFix) {
                await LogService().log(
                  '综测',
                  '检测到综测成绩学号(${score.xsbh})与当前账号($currentUsername)不一致，准备强制刷新会话后重试',
                );
                await _forceRefreshEvaluationSession();
                return await doRequest(allowCrossUserFix: false);
              }
              await LogService().log(
                '综测',
                '二次请求后综测成绩学号(${score.xsbh})仍与当前账号($currentUsername)不一致，已放弃展示该数据',
              );
              return null;
            }
          }
          return score;
        }
      }
      throw Exception('综测成绩结构异常: ${_summarizeResponse(resData)}');
    }

    try {
      return await doRequest();
    } catch (e) {
      if (CampusAccessService.isCampusNetworkUnavailableError(e) ||
          e is CampusServiceUnavailableException) {
        rethrow;
      }
      await LogService().log('综测', '获取综测成绩失败: $e');
      await LogService().logXgTrace(
        XgTraceLogEntry(
          phase: 'service',
          event: 'get_score_failed',
          module: 'zhcptybbapp',
          page: 'xg_evaluation_service',
          requestKey: 'evaluation_score',
          elapsedMs: stopwatch.elapsedMilliseconds,
          result: 'error',
          reason: e.runtimeType.toString(),
          extra: <String, dynamic>{
            'message': e.toString(),
            'semester': semester.displayName,
          },
        ),
      );
      return null;
    }
  }

  /// 强制刷新智慧学工综测模块会话，防止账号串号。
  Future<void> _forceRefreshEvaluationSession() async {
    try {
      await XgSessionCoordinator.instance.prepareStudentModule(
        readModule,
        forceRefresh: true,
        source: 'evaluation_cross_user_fix',
      );
      await LogService().log('综测', '已强制刷新综测学生态主会话');
    } catch (e) {
      await LogService().log('综测', '强制刷新综测模块会话失败: $e');
    }
  }
}
