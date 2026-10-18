import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'campus_access_service.dart';
import 'home_data_cache_codec.dart';
import 'log_service.dart';
import 'schedule_service.dart';
import 'session_store.dart';
import 'sso_service.dart';
import 'token_refresh_service.dart';

class HomeDataScheduleLoader {
  final SessionStore store;
  final ScheduleService scheduleService;
  final TokenRefreshService tokenRefresh;
  final LogService logger;
  final Future<String> Function({
    required String accessToken,
    bool forceRefresh,
  })
  ensureValidMobileToken;
  final bool Function(Object error) shouldRetryWithTokenRefresh;

  const HomeDataScheduleLoader({
    required this.store,
    required this.scheduleService,
    required this.tokenRefresh,
    required this.logger,
    required this.ensureValidMobileToken,
    required this.shouldRetryWithTokenRefresh,
  });

  Future<List<Map<String, String>>?> loadScheduleCached() async {
    final termId = await store.getScheduleSelectedTermId();
    final todayCache = await store.getTodayCoursesCache(termId: termId);
    if (todayCache != null) {
      debugPrint('[今日课程] 使用快速缓存,极速加载!');
      return todayCache;
    }

    final cachedJson = await store.getScheduleData(termId: termId);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      debugPrint('[今日课程] 快速缓存失效,降级到完整课表缓存');
      final data = parseScheduleCache(cachedJson);
      if (data != null) {
        return scheduleService.parseTodayCourses(data);
      }
    }

    return null;
  }

  Future<List<Map<String, String>>> loadScheduleFresh() async {
    try {
      return await _loadScheduleFromNetworkInternal();
    } catch (e) {
      final cached = await loadScheduleCached();
      if (cached != null &&
          (e is CampusServiceUnavailableException ||
              CampusAccessService.isCampusNetworkUnavailableError(e))) {
        return cached;
      }
      if (CampusAccessService.isCampusNetworkUnavailableError(e)) {
        throw CampusServiceUnavailableException('课表', cause: e);
      }
      rethrow;
    }
  }

  Future<void> warmFullScheduleCache() async {
    final token = await store.getAccessToken();
    if (token == null || token.isEmpty) {
      await logger.log('课表', '完整课表预热跳过：当前未登录');
      return;
    }

    try {
      await logger.log('课表', '开始预热完整课表缓存');

      String mobileToken;
      final cachedToken = await store.getYdjwToken();
      if (SsoService.isValidMobileToken(cachedToken)) {
        mobileToken = cachedToken!;
        await logger.log('课表', '完整课表预热使用现有移动端Token');
      } else {
        if (cachedToken != null && cachedToken.isNotEmpty) {
          await store.clearYdjwToken();
          await logger.log('课表', '完整课表预热清理失效移动端Token');
        }
        mobileToken = await ensureValidMobileToken(
          accessToken: token,
          forceRefresh: true,
        ).timeout(const Duration(seconds: 15));
        await logger.log('课表', '完整课表预热已重新获取移动端Token');
      }

      final term = await _resolveScheduleTerm(mobileToken);

      final scheduleData = await scheduleService
          .fetchFullSchedule(mobileToken, termId: term.id)
          .timeout(const Duration(seconds: 15));
      if (scheduleData == null) {
        throw Exception('完整课表预热返回空数据');
      }

      await _saveAndParseSchedule(
        scheduleData,
        termId: term.id,
        termName: term.name,
      );
      await logger.log('课表', '完整课表预热成功并已写入缓存');
    } catch (e) {
      await logger.log('课表', '完整课表预热失败: $e');
    }
  }

  Future<List<Map<String, String>>> _loadScheduleFromNetworkInternal() async {
    final token = await store.getAccessToken();
    if (token == null) throw Exception('未登录');

    final cachedToken = await store.getYdjwToken();

    if (SsoService.isValidMobileToken(cachedToken)) {
      try {
        debugPrint('[今日课程] 尝试使用缓存的移动端Token');

        final term = await _resolveScheduleTerm(cachedToken!);

        final scheduleData = await scheduleService
            .fetchFullSchedule(cachedToken, termId: term.id)
            .timeout(const Duration(seconds: 15));

        if (scheduleData != null) {
          debugPrint('[今日课程] 使用缓存Token获取课表成功');
          return await _saveAndParseSchedule(
            scheduleData,
            termId: term.id,
            termName: term.name,
          );
        }
        throw const CampusServiceUnavailableException('课表');
      } catch (e) {
        if (SsoService.shouldRefreshMobileTokenForError(e)) {
          await store.clearYdjwToken();
          debugPrint('[今日课程] 检测到缓存Token可能失效，已清除并重新执行SSO');
        }
        debugPrint('[今日课程] 使用缓存Token失败: $e,将重新执行SSO');
      }
    } else if (cachedToken != null && cachedToken.isNotEmpty) {
      await store.clearYdjwToken();
      debugPrint('[今日课程] 检测到缓存Token已过期或格式非法，已清除');
    }

    debugPrint('[今日课程] 执行完整SSO流程获取移动端Token');
    final mobileToken = await ensureValidMobileToken(
      accessToken: token,
      forceRefresh: true,
    ).timeout(const Duration(seconds: 15));

    try {
      final term = await _resolveScheduleTerm(mobileToken);
      final scheduleData = await scheduleService
          .fetchFullSchedule(mobileToken, termId: term.id)
          .timeout(const Duration(seconds: 15));
      if (scheduleData == null) {
        throw const CampusServiceUnavailableException('课表');
      }

      return await _saveAndParseSchedule(
        scheduleData,
        termId: term.id,
        termName: term.name,
      );
    } catch (e) {
      if (SsoService.isCorruptedMobileTokenError(e)) {
        await store.clearYdjwToken();
      }
      rethrow;
    }
  }

  Future<ScheduleTerm> _resolveScheduleTerm(String mobileToken) async {
    final selectedTermId = await store.getScheduleSelectedTermId();
    if (selectedTermId != null && selectedTermId.isNotEmpty) {
      return ScheduleTerm(
        id: selectedTermId,
        name: selectedTermId,
        isCurrent: false,
      );
    }

    final terms = await scheduleService.fetchTerms(mobileToken);
    final selectedTerm =
        terms.where((term) => term.isCurrent).firstOrNull ??
        (terms.isNotEmpty ? terms.first : null);
    if (selectedTerm == null || selectedTerm.id.isEmpty) {
      throw Exception('未获取到可用课表学期');
    }
    await store.saveScheduleSelectedTermId(selectedTerm.id);
    return selectedTerm;
  }

  Future<List<Map<String, String>>> _saveAndParseSchedule(
    Map<String, dynamic> scheduleData, {
    required String termId,
    String? termName,
  }) async {
    await store.saveScheduleData(
      jsonEncode(scheduleData),
      termId: termId,
      termName: termName,
    );

    final todayCourses = scheduleService.parseTodayCourses(scheduleData);

    await store.saveTodayCoursesCache(todayCourses, termId: termId);
    debugPrint('[今日课程] 已保存快速缓存,下次打开将极速加载');

    return todayCourses;
  }
}
