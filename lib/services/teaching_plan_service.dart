import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_urls.dart';
import '../utils/error_handler.dart';
import 'campus_access_service.dart';
import 'session_store.dart';
import 'sso_service.dart';

class TeachingPlanCourse {
  final String semester;
  final String courseCode;
  final String courseName;
  final String department;
  final double credit;
  final int totalHours;
  final String assessmentType;
  final String courseNature;
  final String courseAttribute;
  final String isExam;
  final String teachingContext;
  final String planId;

  const TeachingPlanCourse({
    required this.semester,
    required this.courseCode,
    required this.courseName,
    required this.department,
    required this.credit,
    required this.totalHours,
    required this.assessmentType,
    required this.courseNature,
    required this.courseAttribute,
    required this.isExam,
    required this.teachingContext,
    required this.planId,
  });

  factory TeachingPlanCourse.fromJson(Map<String, dynamic> json) {
    return TeachingPlanCourse(
      semester: json['kkxq']?.toString() ?? '',
      courseCode: json['kch']?.toString() ?? '',
      courseName: json['kc_mc']?.toString() ?? '',
      department: json['yx_mc']?.toString() ?? '',
      credit: double.tryParse(json['xf']?.toString() ?? '0') ?? 0,
      totalHours: int.tryParse(json['zxs']?.toString() ?? '0') ?? 0,
      assessmentType: json['khlb_mc']?.toString() ?? '',
      courseNature: json['kcxz_mc']?.toString() ?? '',
      courseAttribute: json['kclb_mc']?.toString() ?? '',
      isExam: json['sfks']?.toString() ?? '',
      teachingContext: json['kctxmc']?.toString() ?? '',
      planId: json['jx02id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kkxq': semester,
      'kch': courseCode,
      'kc_mc': courseName,
      'yx_mc': department,
      'xf': credit,
      'zxs': totalHours,
      'khlb_mc': assessmentType,
      'kcxz_mc': courseNature,
      'kclb_mc': courseAttribute,
      'sfks': isExam,
      'kctxmc': teachingContext,
      'jx02id': planId,
    };
  }
}

class TeachingPlanData {
  final List<TeachingPlanCourse> courses;
  final int totalCount;

  const TeachingPlanData({required this.courses, required this.totalCount});

  factory TeachingPlanData.empty() {
    return const TeachingPlanData(courses: <TeachingPlanCourse>[], totalCount: 0);
  }

  factory TeachingPlanData.fromApi(Map<String, dynamic> json) {
    final rawList = json['data'] as List? ?? const [];
    final courses = rawList
        .whereType<Map>()
        .map(
          (item) => TeachingPlanCourse.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
    final totalCount =
        int.tryParse(json['count']?.toString() ?? '${courses.length}') ??
        courses.length;
    return TeachingPlanData(courses: courses, totalCount: totalCount);
  }

  factory TeachingPlanData.fromCache(Map<String, dynamic> json) {
    final rawList = json['courses'] as List? ?? const [];
    final courses = rawList
        .whereType<Map>()
        .map(
          (item) => TeachingPlanCourse.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
    final totalCount =
        int.tryParse(json['totalCount']?.toString() ?? '${courses.length}') ??
        courses.length;
    return TeachingPlanData(courses: courses, totalCount: totalCount);
  }

  Map<String, dynamic> toCacheJson() {
    return <String, dynamic>{
      'totalCount': totalCount,
      'courses': courses.map((item) => item.toJson()).toList(),
    };
  }
}

class TeachingPlanService {
  TeachingPlanService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 12),
              followRedirects: true,
              maxRedirects: 5,
              validateStatus: (status) => status != null && status < 500,
            ),
          ) {
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  final Dio _dio;
  final CookieJar _cookieJar = CookieJar();
  final SessionStore _store = SessionStore();
  final SsoService _ssoService = SsoService();

  Future<void> _ensureWebSession() async {
    final accessToken = await _store.getAccessToken();
    final username = await _store.getUsername();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('未获取到统一认证Token，请先重新登录');
    }
    if (username == null || username.isEmpty) {
      throw Exception('未获取到当前用户名，无法进入教务系统');
    }

    final sessionUri = Uri.parse('${ApiUrls.jwWebUrl}/jsxsd/framework/xsMainV.htmlx');
    final existingCookies = await _cookieJar.loadForRequest(sessionUri);
    final hasSession = existingCookies.any(
      (cookie) => cookie.name == 'bzb_jsxsd' && cookie.value.isNotEmpty,
    );
    if (hasSession) {
      return;
    }

    final result = await _ssoService.runSso(accessToken, username);
    if (!result.hasCookies) {
      throw Exception('教务系统会话建立失败');
    }

    final cookies = <Cookie>[];
    if ((result.bzbJsxsd ?? '').isNotEmpty) {
      cookies.add(
        Cookie('bzb_jsxsd', result.bzbJsxsd!)
          ..path = '/jsxsd'
          ..secure = true
          ..httpOnly = true,
      );
    }
    if ((result.serverIdJsxsd ?? '').isNotEmpty) {
      cookies.add(
        Cookie('SERVERID_jsxsd', result.serverIdJsxsd!)
          ..path = '/'
          ..secure = true
          ..httpOnly = false,
      );
    }
    if (cookies.isEmpty) {
      throw Exception('未获取到教务系统Cookie');
    }

    await _cookieJar.saveFromResponse(sessionUri, cookies);
    if (result.bzbJsxsd != null && result.serverIdJsxsd != null) {
      await _store.saveJwCookies(
        bzbJsxsd: result.bzbJsxsd!,
        serverIdJsxsd: result.serverIdJsxsd!,
      );
    }
  }

  Future<TeachingPlanData> _fetchPage({
    required int pageNum,
    required int pageSize,
  }) async {
    final response = await _dio.get(
      '${ApiUrls.jwWebUrl}/jsxsd/pyfa/pyfa_query',
      queryParameters: <String, dynamic>{
        'islist': 1,
        'pageNum': pageNum,
        'pageSize': pageSize,
      },
      options: Options(
        responseType: ResponseType.json,
        headers: <String, dynamic>{
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Referer': '${ApiUrls.jwWebUrl}/jsxsd/pyfa/pyfa_query',
          'User-Agent': _userAgent,
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw Exception('教学计划接口返回异常状态');
    }

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : jsonDecode(response.data.toString()) as Map<String, dynamic>;
    final msg = data['msg']?.toString() ?? '';
    if (msg.isNotEmpty) {
      throw Exception(msg);
    }
    return TeachingPlanData.fromApi(data);
  }

  Future<TeachingPlanData> _fetchAllFromNetwork() async {
    await _ensureWebSession();

    final firstPage = await _fetchPage(pageNum: 1, pageSize: 200);
    if (firstPage.courses.isEmpty || firstPage.totalCount <= firstPage.courses.length) {
      await _store.saveTeachingPlanData(jsonEncode(firstPage.toCacheJson()));
      return firstPage;
    }

    final allCourses = <TeachingPlanCourse>[...firstPage.courses];
    final totalCount = firstPage.totalCount;
    final totalPages = (totalCount / 200).ceil();
    for (int page = 2; page <= totalPages; page++) {
      final nextPage = await _fetchPage(pageNum: page, pageSize: 200);
      allCourses.addAll(nextPage.courses);
    }

    final merged = TeachingPlanData(courses: allCourses, totalCount: totalCount);
    await _store.saveTeachingPlanData(jsonEncode(merged.toCacheJson()));
    return merged;
  }

  Future<TeachingPlanData> fetchAllCourses() async {
    return ErrorHandler.handle(
      () async {
        try {
          return await _fetchAllFromNetwork();
        } catch (error) {
          final cached = await loadFromCache();
          if (cached.courses.isNotEmpty) {
            debugPrint('DEBUG: 教学计划网络失败，使用本地缓存: $error');
            return cached;
          }
          if (CampusAccessService.isCampusNetworkUnavailableError(error)) {
            throw CampusServiceUnavailableException('教学计划', cause: error);
          }
          rethrow;
        }
      },
      action: '获取教学计划',
      defaultValue: TeachingPlanData.empty(),
    );
  }

  Future<TeachingPlanData> loadFromCache() async {
    return ErrorHandler.handle(
      () async {
        final cached = await _store.getTeachingPlanData();
        if (cached == null || cached.isEmpty) {
          return TeachingPlanData.empty();
        }
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        return TeachingPlanData.fromCache(decoded);
      },
      action: '读取教学计划缓存',
      defaultValue: TeachingPlanData.empty(),
    );
  }
}
