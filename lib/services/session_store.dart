import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/xg_module_session_snapshot.dart';
import '../models/user_info.dart';
import 'storage/auth_store.dart';
import 'storage/xg_cache_store.dart';

class SessionStore extends AuthStore {
  static final Map<String, String> _memoryFallback = <String, String>{};
  static const _kXgSessionUser = 'xg_session_user';
  static const _kXgSessionSnapshot = 'xg_session_snapshot';
  static const _kXgSessionRole = 'xg_session_role';
  static const _kXgSessionGroupRefreshedAt = 'xg_session_group_refreshed_at';
  static const _kXgModuleSnapshot = 'xg_module_snapshot';
  static const _kXgEvaluationOverviewCache = 'xg_evaluation_overview_cache';
  static const _kXgTraceCurrentId = 'xg_trace_current_id';
  static const _kXgTraceStartedAt = 'xg_trace_started_at';

  static const _kScheduleData = 'schedule_data';
  static const _kScheduleSelectedTermId = 'schedule_selected_term_id';
  static const _kTodayCoursesCache = 'today_courses_cache'; // 今日课程快速缓存
  static const _kTodayCoursesCacheDate = 'today_courses_cache_date'; // 缓存日期
  static const _kDisplayName = 'display_name';
  static const _kCollege = 'college';
  static const _kClassName = 'class_name';
  static const _kUserInfo = 'user_info_cache';
  static const _kPortalAnnouncements = 'portal_announcements_cache'; // 门户公告缓存
  static const _kTeachingPlanData = 'teaching_plan_data';

  XgCacheStore get _xgCacheStore => XgCacheStore(
    setScopedString: setScopedString,
    getScopedString: getScopedString,
    removeKeysWithPrefix: removeKeysWithPrefix,
    xgSessionUserKey: _kXgSessionUser,
    xgSessionSnapshotKey: _kXgSessionSnapshot,
    xgSessionRoleKey: _kXgSessionRole,
    xgSessionGroupRefreshedAtKey: _kXgSessionGroupRefreshedAt,
    xgModuleSnapshotKey: _kXgModuleSnapshot,
    xgEvaluationOverviewCacheKey: _kXgEvaluationOverviewCache,
  );

  /// 保存门户公告
  Future<void> savePortalAnnouncements(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPortalAnnouncements, json);
  }

  /// 获取门户公告
  Future<String?> getPortalAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPortalAnnouncements);
  }

  Future<void> saveUserInfo(UserInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserInfo, jsonEncode(info.toJson()));
  }

  Future<UserInfo?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kUserInfo);
    if (jsonStr == null) return null;
    try {
      return UserInfo.fromCache(jsonDecode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  static const _kGradeData = 'grade_data';

  Future<void> saveGradeData(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGradeData, json);
  }

  Future<String?> getGradeData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kGradeData);
  }

  Future<void> saveTeachingPlanData(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await setScopedString(prefs, _kTeachingPlanData, json);
  }

  Future<String?> getTeachingPlanData() async {
    final prefs = await SharedPreferences.getInstance();
    return getScopedString(prefs, _kTeachingPlanData);
  }

  Future<void> saveXgSessionUser(String username) async {
    await _xgCacheStore.saveXgSessionUser(username);
    _memoryFallback[_kXgSessionUser] = username;
  }

  Future<String?> getXgSessionUser() async {
    final value = await _xgCacheStore.getXgSessionUser();
    return value ?? _memoryFallback[_kXgSessionUser];
  }

  Future<void> clearLegacyXgSessionArtifacts() async {
    await _xgCacheStore.clearLegacyXgSessionArtifacts();
    _memoryFallback.removeWhere(
      (key, _) =>
          key.startsWith(_kXgSessionSnapshot) ||
          key.startsWith(_kXgSessionRole) ||
          key.startsWith(_kXgSessionGroupRefreshedAt),
    );
  }

  Future<void> clearAllXgSessionSnapshots() async {
    await _xgCacheStore.clearAllXgSessionSnapshots();
    _memoryFallback.removeWhere((key, _) => key.startsWith(_kXgModuleSnapshot));
  }

  Future<void> saveXgModuleSnapshot(XgModuleSessionSnapshot snapshot) async {
    await _xgCacheStore.saveXgModuleSnapshot(snapshot);
  }

  Future<XgModuleSessionSnapshot?> getXgModuleSnapshot(String appName) async {
    return _xgCacheStore.getXgModuleSnapshot(appName);
  }

  Future<void> clearXgModuleSnapshot(String appName) async {
    await _xgCacheStore.clearXgModuleSnapshot(appName);
  }

  Future<void> saveXgEvaluationOverviewCache(String json) async {
    await _xgCacheStore.saveXgEvaluationOverviewCache(json);
  }

  Future<String?> getXgEvaluationOverviewCache() async {
    return _xgCacheStore.getXgEvaluationOverviewCache();
  }

  Future<void> clearXgEvaluationOverviewCache() async {
    await _xgCacheStore.clearXgEvaluationOverviewCache();
  }

  Future<void> saveXgTraceCurrentId(String? traceId) async {
    final prefs = await SharedPreferences.getInstance();
    if (traceId == null || traceId.isEmpty) {
      await prefs.remove(_kXgTraceCurrentId);
      return;
    }
    await prefs.setString(_kXgTraceCurrentId, traceId);
  }

  Future<String?> getXgTraceCurrentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kXgTraceCurrentId);
  }

  Future<void> saveXgTraceStartedAt(DateTime? startedAt) async {
    final prefs = await SharedPreferences.getInstance();
    if (startedAt == null) {
      await prefs.remove(_kXgTraceStartedAt);
      return;
    }
    await prefs.setString(
      _kXgTraceStartedAt,
      startedAt.toUtc().toIso8601String(),
    );
  }

  Future<void> saveScheduleData(
    String jsonStr, {
    required String termId,
    String? termName,
  }) async {
    if (termId.isEmpty) {
      throw ArgumentError.value(termId, 'termId', '课表缓存必须绑定学期');
    }
    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(jsonStr);
    if (data is! Map) {
      throw const FormatException('课表缓存数据格式无效');
    }
    final cacheData = Map<String, dynamic>.from(data)
      ..['_cache_term_id'] = termId
      ..['_cache_term_name'] = termName ?? ''
      ..['_cache_saved_at'] = DateTime.now().toIso8601String();
    await setScopedString(
      prefs,
      '${_kScheduleData}_$termId',
      jsonEncode(cacheData),
    );
  }

  Future<String?> getScheduleData({String? termId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (termId != null && termId.isNotEmpty) {
      final termCache = await getScopedString(
        prefs,
        '${_kScheduleData}_$termId',
      );
      if (termCache != null && termCache.isNotEmpty) {
        return termCache;
      }
    } else {
      final selectedTermId = prefs.getString(_kScheduleSelectedTermId);
      if (selectedTermId != null && selectedTermId.isNotEmpty) {
        final selectedTermCache = await getScopedString(
          prefs,
          '${_kScheduleData}_$selectedTermId',
        );
        if (selectedTermCache != null && selectedTermCache.isNotEmpty) {
          return selectedTermCache;
        }
      }
    }

    return null;
  }

  /// 返回当前账号已有完整课表缓存对应的学期选项。
  Future<List<Map<String, String>>> getCachedScheduleTerms() async {
    final prefs = await SharedPreferences.getInstance();
    final scopes = getCacheScopes(prefs);
    if (scopes.isEmpty) {
      return const [];
    }

    final cachedTerms = <String, Map<String, String>>{};
    const cachePrefix = '${_kScheduleData}_';
    for (final key in prefs.getKeys()) {
      for (final scope in scopes) {
        final scopedSuffix = '${AuthStore.kScopedSeparator}$scope';
        if (!key.startsWith(cachePrefix) || !key.endsWith(scopedSuffix)) {
          continue;
        }

        final termIdEnd = key.length - scopedSuffix.length;
        // 旧版通用 schedule_data 缓存没有学期 ID，直接忽略。
        if (termIdEnd <= cachePrefix.length) {
          continue;
        }
        final keyTermId = key.substring(cachePrefix.length, termIdEnd);
        if (keyTermId.isEmpty) {
          continue;
        }

        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) {
          continue;
        }

        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) {
            continue;
          }
          final data = Map<String, dynamic>.from(decoded);
          final cachedId = data['_cache_term_id']?.toString().trim() ?? '';
          final termId = cachedId.isEmpty ? keyTermId : cachedId;
          final termName = data['_cache_term_name']?.toString().trim() ?? '';
          cachedTerms[termId] = {
            'id': termId,
            'name': termName.isEmpty ? termId : termName,
          };
        } catch (_) {
          // 忽略损坏的单个缓存，不影响其他学期选项。
        }
        break;
      }
    }

    final terms = cachedTerms.values.toList();
    terms.sort((a, b) => b['id']!.compareTo(a['id']!));
    return terms;
  }

  Future<void> clearScheduleData({String? termId}) async {
    final prefs = await SharedPreferences.getInstance();
    final baseKey = (termId == null || termId.isEmpty)
        ? _kScheduleData
        : '${_kScheduleData}_$termId';
    await removeKeysWithPrefix(prefs, baseKey);
  }

  Future<void> saveScheduleSelectedTermId(String? termId) async {
    final prefs = await SharedPreferences.getInstance();
    if (termId == null || termId.isEmpty) {
      await prefs.remove(_kScheduleSelectedTermId);
      return;
    }
    await prefs.setString(_kScheduleSelectedTermId, termId);
  }

  Future<String?> getScheduleSelectedTermId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kScheduleSelectedTermId);
  }

  /// 保存今日课程快速缓存（避免每次都解析完整课表JSON）
  Future<void> saveTodayCoursesCache(
    List<Map<String, String>> courses, {
    required String termId,
  }) async {
    if (termId.isEmpty) {
      throw ArgumentError.value(termId, 'termId', '今日课程缓存必须绑定学期');
    }
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await setScopedString(
      prefs,
      '${_kTodayCoursesCache}_$termId',
      jsonEncode(courses),
    );
    await setScopedString(prefs, '${_kTodayCoursesCacheDate}_$termId', dateKey);
  }

  /// 获取今日课程快速缓存（如果是同一天直接返回，否则返回null）
  Future<List<Map<String, String>>?> getTodayCoursesCache({
    String? termId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedTermId = termId?.isNotEmpty == true
        ? termId
        : prefs.getString(_kScheduleSelectedTermId);
    if (resolvedTermId == null || resolvedTermId.isEmpty) {
      return null;
    }
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final cachedDate = await getScopedString(
      prefs,
      '${_kTodayCoursesCacheDate}_$resolvedTermId',
    );

    // 如果不是今天的缓存，返回null
    if (cachedDate != dateKey) {
      return null;
    }

    final cachedJson = await getScopedString(
      prefs,
      '${_kTodayCoursesCache}_$resolvedTermId',
    );
    if (cachedJson == null) return null;

    try {
      final List<dynamic> list = jsonDecode(cachedJson);
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDisplayName, name);
  }

  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDisplayName);
  }

  Future<void> saveUserInfoDetails({
    required String college,
    required String className,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCollege, college);
    await prefs.setString(_kClassName, className);
  }

  Future<Map<String, String>> getUserInfoDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'college': prefs.getString(_kCollege) ?? '',
      'className': prefs.getString(_kClassName) ?? '',
    };
  }

  /// 清除用户级缓存与会话数据，但保留记住密码、自动登录及已保存密码设置。
  Future<void> clearUserScopedData() async {
    final prefs = await SharedPreferences.getInstance();

    await clearAccessToken();
    await prefs.remove(AuthStore.kYdjwToken);
    await prefs.remove(AuthStore.kUsername);
    await prefs.remove(AuthStore.kBzbJsxsd);
    await prefs.remove(AuthStore.kServerIdJsxsd);
    await prefs.remove(_kXgSessionUser);
    await clearAllXgSessionSnapshots();

    await prefs.remove(_kDisplayName);
    await prefs.remove(_kCollege);
    await prefs.remove(_kClassName);
    await prefs.remove(_kUserInfo);

    await prefs.remove(_kGradeData);
    await removeKeysWithPrefix(prefs, _kTeachingPlanData);
    await removeKeysWithPrefix(prefs, _kScheduleData);
    await prefs.remove(_kScheduleSelectedTermId);
    await prefs.remove(_kPortalAnnouncements);
    await removeKeysWithPrefix(prefs, _kTodayCoursesCache);
    await removeKeysWithPrefix(prefs, _kTodayCoursesCacheDate);
    await removeKeysWithPrefix(prefs, _kXgEvaluationOverviewCache);
    await prefs.remove(_kXgTraceCurrentId);
    await prefs.remove(_kXgTraceStartedAt);
  }

  Future<void> clearSavedLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AuthStore.kUsername);
    await clearPassword();
    await prefs.remove(AuthStore.kRememberPassword);
    await prefs.remove(AuthStore.kAutoLogin);
  }

  /// 仅清除认证会话，保留账号、密码与业务缓存。
  ///
  /// 用于启动阶段检测到登录态失效时，避免把账号输入框一并清空。
  Future<void> clearAuthSession({bool clearAutoLogin = false}) async {
    final prefs = await SharedPreferences.getInstance();

    await clearAccessToken();
    await prefs.remove(AuthStore.kYdjwToken);
    await prefs.remove(AuthStore.kBzbJsxsd);
    await prefs.remove(AuthStore.kServerIdJsxsd);
    await prefs.remove(_kXgSessionUser);
    await clearAllXgSessionSnapshots();
    await prefs.remove(_kXgTraceCurrentId);
    await prefs.remove(_kXgTraceStartedAt);

    if (clearAutoLogin) {
      await prefs.remove(AuthStore.kAutoLogin);
    }
  }

  /// 清除会话数据 (退出登录)
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await clearUserScopedData();

    // 如果没勾选记住密码，则清除密码
    if (prefs.getBool(AuthStore.kRememberPassword) != true) {
      await clearPassword();
    }

    // 自动登录标志也应清除
    await prefs.remove(AuthStore.kAutoLogin);
  }
}
