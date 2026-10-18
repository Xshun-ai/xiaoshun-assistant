import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../constants/api_urls.dart';
import 'session_store.dart';
import 'sso_service.dart';
import '../utils/error_handler.dart';

/// 成绩详情实体类
class Grade {
  /// 课程名称
  final String courseName;

  /// 成绩
  final String score;

  /// 学分
  final double credit;

  /// 绩点
  final double gpa;

  /// 课程属性 (必修/选修)
  final String attribute;

  /// 课程性质 (专业课/公共课)
  final String nature;

  /// 考核方式 (考试/考查)
  final String examType;

  /// 是否通过
  final bool isPassed;

  Grade({
    required this.courseName,
    required this.score,
    required this.credit,
    required this.gpa,
    required this.attribute,
    required this.nature,
    required this.examType,
    required this.isPassed,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      courseName: json['courseName']?.toString() ?? '',
      score: json['fraction']?.toString() ?? '',
      credit: double.tryParse(json['credit']?.toString() ?? '0') ?? 0.0,
      gpa: double.tryParse(json['jd']?.toString() ?? '0') ?? 0.0,
      attribute: json['curriculumAttributes']?.toString() ?? '',
      nature: json['courseNature']?.toString() ?? '',
      examType: json['examName']?.toString() ?? '',
      isPassed: (json['sfjg']?.toString() ?? '不合格') == '合格',
    );
  }
}

/// 学期实体类
class Semester {
  final String id;
  final String name;
  final bool isCurrent;

  Semester({required this.id, required this.name, required this.isCurrent});

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['semesterId']?.toString() ?? '',
      name: json['semesterName']?.toString() ?? '',
      isCurrent: (json['nowXq']?.toString() ?? '0') == '1',
    );
  }
}

/// 成绩查询服务
class GradeService {
  final Dio _dio;
  final SessionStore _sessionStore;
  final SsoService _ssoService;

  GradeService([Dio? dio])
    : _dio = dio ?? Dio(),
      _sessionStore = SessionStore(),
      _ssoService = SsoService();

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  Future<String> _getValidMobileToken({bool forceRefresh = false}) async {
    final cachedToken = forceRefresh
        ? null
        : await _sessionStore.getYdjwToken();
    if (SsoService.isValidMobileToken(cachedToken)) {
      return cachedToken!;
    }

    if (cachedToken != null && cachedToken.isNotEmpty) {
      await _sessionStore.clearYdjwToken();
    }

    final accessToken = await _sessionStore.getAccessToken();
    final username = await _sessionStore.getUsername();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('未获取到统一认证Token，请先重新登录');
    }
    if (username == null || username.isEmpty) {
      throw Exception('未获取到当前用户名，无法执行移动端SSO');
    }

    return _ssoService.ensureValidMobileToken(
      store: _sessionStore,
      accessToken: accessToken,
      username: username,
      forceRefresh: true,
    );
  }

  /// 获取通用请求头
  Future<Options> _getOptions({bool forceRefreshToken = false}) async {
    final token = await _getValidMobileToken(forceRefresh: forceRefreshToken);
    return Options(
      contentType: 'application/x-www-form-urlencoded',
      headers: {'Token': token, 'User-Agent': _userAgent},
    );
  }

  Future<Map<String, List<Grade>>> _fetchAllGradesFromNetwork({
    bool forceRefreshToken = false,
  }) async {
    final options = await _getOptions(forceRefreshToken: forceRefreshToken);
    final url = '${ApiUrls.jwBaseUrl}/njwhd/student/termGPA?semester=&type=1';

    final resp = await _dio
        .post(url, options: options)
        .timeout(const Duration(seconds: 3));

    if (resp.statusCode == 200 && resp.data != null) {
      final dataList = resp.data['data'] as List?;
      if (dataList != null && dataList.isNotEmpty) {
        _sessionStore.saveGradeData(jsonEncode(resp.data));
        return _parseGrades(resp.data);
      }
    }

    throw Exception('成绩接口返回空数据');
  }

  /// 获取完整的成绩数据并缓存
  ///
  /// 一次性获取所有学期的成绩数据
  /// 返回 `Map<String, List<Grade>>`，key 为学期 ID（如 `2024-2025-1`）
  Future<Map<String, List<Grade>>> fetchAllGrades() async {
    return ErrorHandler.handle(
      () async {
        try {
          return await _fetchAllGradesFromNetwork();
        } catch (e) {
          if (SsoService.shouldRefreshMobileTokenForError(e)) {
            await _sessionStore.clearYdjwToken();
            debugPrint('DEBUG: 检测到移动端Token可能失效，清除后强制重试成绩请求');
            try {
              return await _fetchAllGradesFromNetwork(forceRefreshToken: true);
            } catch (retryError) {
              debugPrint('DEBUG: 强制刷新移动端Token后获取成绩仍失败: $retryError');
              if (SsoService.isCorruptedMobileTokenError(retryError)) {
                await _sessionStore.clearYdjwToken();
              }
            }
          } else if (SsoService.isCorruptedMobileTokenError(e)) {
            await _sessionStore.clearYdjwToken();
          }
          debugPrint('DEBUG: 网络请求失败 ($e)，尝试使用缓存');
        }

        // 如果网络请求失败或返回空数据，尝试使用缓存
        final cachedJson = await _sessionStore.getGradeData();
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final data = jsonDecode(cachedJson);
          debugPrint('DEBUG: 使用本地成绩缓存（网络异常降级）');
          return _parseGrades(data);
        }

        // 无缓存可用，返回空Map（预热场景不阻塞应用）
        debugPrint('DEBUG: 获取成绩失败且无缓存数据，返回空结果');
        return <String, List<Grade>>{};
      },
      action: '获取全部成绩',
      defaultValue: {},
    );
  }

  /// 从本地缓存加载成绩
  Future<Map<String, List<Grade>>> loadFromCache() async {
    return ErrorHandler.handle(
      () async {
        final cachedJson = await _sessionStore.getGradeData();
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final data = jsonDecode(cachedJson);
          return _parseGrades(data);
        }
        return <String, List<Grade>>{};
      },
      action: '读取成绩缓存',
      defaultValue: {},
    );
  }

  /// 解析API返回的完整成绩数据
  Map<String, List<Grade>> _parseGrades(Map<String, dynamic> data) {
    final Map<String, List<Grade>> allGrades = {};

    final dataList = data['data'] as List?;
    if (dataList != null && dataList.isNotEmpty) {
      final achievementList = dataList[0]['achievement'] as List?;
      if (achievementList != null) {
        for (var item in achievementList) {
          final grade = Grade.fromJson(item);
          // kkxq 是学期ID，如 "2023-2024-1"
          final termId = item['kkxq']?.toString() ?? 'unknown';

          if (!allGrades.containsKey(termId)) {
            allGrades[termId] = [];
          }
          allGrades[termId]!.add(grade);
        }
      }
    }
    return allGrades;
  }

  /// 获取学期列表 (从缓存的成绩数据中提取)
  Future<List<Semester>> getSemesters() async {
    // ... (不再单独请求API，改为从 fetchAllGrades 的结果或缓存中提取)
    // 这里保留是为了兼容旧代码，但建议重构为直接从 allGrades.keys 生成
    // 实际实现将在 GradePage 中处理
    return [];
  }
}
