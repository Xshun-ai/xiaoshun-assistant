import 'dart:async';

import '../models/xg_module_session_snapshot.dart';
import 'campus_access_service.dart';
import 'log_service.dart';
import 'session_store.dart';
import 'sso_service.dart';
import 'token_refresh_service.dart';
import 'xg_http.dart';

class XgSessionCoordinator {
  XgSessionCoordinator._internal();

  static final XgSessionCoordinator instance = XgSessionCoordinator._internal();
  static const Duration _moduleReadyTtl = Duration(minutes: 20);

  final SessionStore _store = SessionStore();
  final Map<String, Future<void>> _studentTasks = <String, Future<void>>{};
  final Map<String, Future<void>> _baseSessionTasks = <String, Future<void>>{};
  final Map<String, Future<bool>> _preloadTasks = <String, Future<bool>>{};

  String _moduleKey(String username, XgModule module) {
    return '$username:${module.appName}';
  }

  String _baseSessionKey(String username) {
    return '$username:xg_base';
  }

  Future<void> _traceSession(XgTraceLogEntry entry) async {
    await LogService().logXgTrace(entry);
  }

  Future<void> _ensureBaseSessionTask({
    required String username,
    required String accessToken,
    String source = 'manual',
  }) async {
    if (!XgHttp.instance.initialized) {
      await XgHttp.instance.init();
    }

    final taskKey = _baseSessionKey(username);
    final existing = _baseSessionTasks[taskKey];
    if (existing != null) {
      await _traceSession(
        XgTraceLogEntry(
          phase: 'session',
          event: 'base_session_reused',
          module: 'xg_base',
          requestKey: taskKey,
          result: 'reused',
          extra: <String, dynamic>{'source': source},
        ),
      );
      await existing;
      return;
    }

    late final Future<void> task;
    task = () async {
      final stopwatch = Stopwatch()..start();
      await _traceSession(
        XgTraceLogEntry(
          phase: 'session',
          event: 'base_session_started',
          module: 'xg_base',
          requestKey: taskKey,
          result: 'started',
          extra: <String, dynamic>{'source': source},
        ),
      );
      try {
        await XgSessionHelper.ensureBaseSession(
          jar: XgHttp.instance.cookieJar,
          accessToken: accessToken,
          username: username,
        );
        await _traceSession(
          XgTraceLogEntry(
            phase: 'session',
            event: 'base_session_finished',
            module: 'xg_base',
            requestKey: taskKey,
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: 'ok',
            extra: <String, dynamic>{'source': source},
          ),
        );
      } catch (e) {
        await _traceSession(
          XgTraceLogEntry(
            phase: 'session',
            event: 'base_session_failed',
            module: 'xg_base',
            requestKey: taskKey,
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: 'error',
            reason: e.runtimeType.toString(),
            extra: <String, dynamic>{'source': source, 'message': e.toString()},
          ),
        );
        rethrow;
      } finally {
        if (identical(_baseSessionTasks[taskKey], task)) {
          _baseSessionTasks.remove(taskKey);
        }
      }
    }();

    _baseSessionTasks[taskKey] = task;
    await task;
  }

  XgSessionStaleReason _mapFailureKindToStaleReason(XgSessionFailureKind kind) {
    switch (kind) {
      case XgSessionFailureKind.timeout:
        return XgSessionStaleReason.timeout;
      case XgSessionFailureKind.moduleExpired:
        return XgSessionStaleReason.http302;
      case XgSessionFailureKind.baseExpired:
        return XgSessionStaleReason.loginHtml;
      case XgSessionFailureKind.schoolTokenExpired:
        return XgSessionStaleReason.unknown;
      case XgSessionFailureKind.network:
        return XgSessionStaleReason.timeout;
      case XgSessionFailureKind.unknown:
        return XgSessionStaleReason.unknown;
    }
  }

  Future<bool> _shouldForceRefreshForUser(String username) async {
    final lastUser = await _store.getXgSessionUser();
    return lastUser != null && lastUser.isNotEmpty && lastUser != username;
  }

  Future<bool> _isSnapshotReusable(
    XgModule module, {
    required String username,
  }) async {
    final snapshot = await _store.getXgModuleSnapshot(module.appName);
    if (snapshot == null) return false;
    if (snapshot.username != username) return false;
    if (snapshot.state != XgModuleSessionState.ready) return false;
    if (snapshot.currentRoleId != XgSessionHelper.studentRoleId) return false;
    final lastReadyAt = snapshot.lastReadyAt;
    if (lastReadyAt == null) return false;
    if (DateTime.now().toUtc().difference(lastReadyAt.toUtc()) >
        _moduleReadyTtl) {
      return false;
    }
    if (!await XgSessionHelper.hasValidWeu(XgHttp.instance.cookieJar)) {
      return false;
    }
    return true;
  }

  Future<void> _saveReadySnapshot(
    XgModule module, {
    required String username,
    required String roleId,
  }) async {
    final now = DateTime.now().toUtc();
    final current = await _store.getXgModuleSnapshot(module.appName);
    final snapshot =
        (current ??
                XgModuleSessionSnapshot(
                  appName: module.appName,
                  username: username,
                  currentRoleId: roleId,
                  state: XgModuleSessionState.ready,
                  snapshotVersion: 1,
                ))
            .copyWith(
              username: username,
              currentRoleId: roleId,
              preparedAt: current?.preparedAt ?? now,
              warmUpVerifiedAt: now,
              lastReadyAt: now,
              state: XgModuleSessionState.ready,
              clearLastFailureReason: true,
            );
    await _store.saveXgModuleSnapshot(snapshot);
    await _store.saveXgSessionUser(username);
  }

  Future<void> _saveStateSnapshot(
    XgModule module, {
    required String username,
    required XgModuleSessionState state,
    required String roleId,
    XgSessionStaleReason? reason,
  }) async {
    final current = await _store.getXgModuleSnapshot(module.appName);
    final now = DateTime.now().toUtc();
    final snapshot =
        (current ??
                XgModuleSessionSnapshot(
                  appName: module.appName,
                  username: username,
                  currentRoleId: roleId,
                  state: state,
                  snapshotVersion: 1,
                ))
            .copyWith(
              username: username,
              currentRoleId: roleId,
              state: state,
              lastFailureAt:
                  state == XgModuleSessionState.failed ||
                      state == XgModuleSessionState.stale
                  ? now
                  : current?.lastFailureAt,
              lastFailureReason: reason,
            );
    await _store.saveXgModuleSnapshot(snapshot);
  }

  Future<void> markModuleStale(
    XgModule module,
    XgSessionStaleReason reason, {
    String? username,
  }) async {
    final effectiveUsername = username ?? await _store.getUsername();
    if (effectiveUsername == null || effectiveUsername.isEmpty) {
      return;
    }
    await _saveStateSnapshot(
      module,
      username: effectiveUsername,
      state: XgModuleSessionState.stale,
      roleId: XgSessionHelper.studentRoleId,
      reason: reason,
    );
  }

  Future<void> prepareStudentModule(
    XgModule module, {
    bool forceRefresh = false,
    String source = 'manual',
  }) async {
    if (!XgHttp.instance.initialized) {
      await XgHttp.instance.init();
    }

    final refreshResult = await TokenRefreshService.waitForOngoingRefresh();
    final didRefreshSchoolToken = refreshResult?.isRefreshed == true;
    if (refreshResult != null) {
      await _traceSession(
        XgTraceLogEntry(
          phase: 'session',
          event: 'prepare_waited_token_refresh',
          module: module.appName,
          requestKey: 'school_token_refresh',
          result: refreshResult.status.name,
          extra: <String, dynamic>{'source': source},
        ),
      );
    }

    final accessToken = await _store.getAccessToken();
    final username = await _store.getUsername();
    if (accessToken == null || accessToken.isEmpty) {
      throw const XgSessionException(
        kind: XgSessionFailureKind.schoolTokenExpired,
        message: '本地无 AccessToken，无法准备智慧学工会话',
      );
    }
    if (username == null || username.isEmpty) {
      throw const XgSessionException(
        kind: XgSessionFailureKind.unknown,
        message: '本地无用户名，无法准备智慧学工会话',
      );
    }

    final moduleKey = _moduleKey(username, module);
    final existing = _studentTasks[moduleKey];
    if (existing != null) {
      await _traceSession(
        XgTraceLogEntry(
          phase: 'session',
          event: 'prepare_reused',
          module: module.appName,
          requestKey: moduleKey,
          result: 'reused',
          extra: <String, dynamic>{'source': source},
        ),
      );
      await existing;
      return;
    }

    final shouldForceRefresh =
        forceRefresh ||
        didRefreshSchoolToken ||
        await _shouldForceRefreshForUser(username);
    final reusable =
        !shouldForceRefresh &&
        await _isSnapshotReusable(module, username: username);
    if (reusable) {
      await _traceSession(
        XgTraceLogEntry(
          phase: 'session',
          event: 'prepare_snapshot_reused',
          module: module.appName,
          requestKey: moduleKey,
          result: 'reused',
          extra: <String, dynamic>{'source': source},
        ),
      );
      return;
    }

    final task = () async {
      final stopwatch = Stopwatch()..start();
      await _traceSession(
        XgTraceLogEntry(
          phase: 'session',
          event: 'prepare_started',
          module: module.appName,
          requestKey: moduleKey,
          result: 'started',
          extra: <String, dynamic>{
            'source': source,
            'forceRefresh': shouldForceRefresh,
            'snapshotReused': reusable,
          },
        ),
      );
      await _saveStateSnapshot(
        module,
        username: username,
        state: shouldForceRefresh
            ? XgModuleSessionState.recovering
            : XgModuleSessionState.preparing,
        roleId: XgSessionHelper.studentRoleId,
        reason: shouldForceRefresh ? XgSessionStaleReason.forcedRefresh : null,
      );

      try {
        await _ensureBaseSessionTask(
          username: username,
          accessToken: accessToken,
          source: source,
        );
        await XgSessionHelper.ensureStudentSession(
          dio: XgHttp.instance.client,
          jar: XgHttp.instance.cookieJar,
          accessToken: accessToken,
          username: username,
          module: module,
          doWarmUp: true,
          forceRefresh: shouldForceRefresh,
        );
        await _saveReadySnapshot(
          module,
          username: username,
          roleId: XgSessionHelper.studentRoleId,
        );
        await _traceSession(
          XgTraceLogEntry(
            phase: 'session',
            event: 'prepare_finished',
            module: module.appName,
            requestKey: moduleKey,
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: 'ok',
            extra: <String, dynamic>{
              'source': source,
              'forceRefresh': shouldForceRefresh,
            },
          ),
        );
        await LogService().log(
          '智慧学工',
          '模块会话已就绪: ${module.appName}, source=$source, forceRefresh=$shouldForceRefresh',
        );
      } catch (e) {
        final reason = e is XgSessionException
            ? _mapFailureKindToStaleReason(e.kind)
            : (CampusAccessService.isCampusNetworkUnavailableError(e) ||
                      e is CampusServiceUnavailableException
                  ? XgSessionStaleReason.timeout
                  : XgSessionStaleReason.unknown);
        await _saveStateSnapshot(
          module,
          username: username,
          state: XgModuleSessionState.failed,
          roleId: XgSessionHelper.studentRoleId,
          reason: reason,
        );
        await _traceSession(
          XgTraceLogEntry(
            phase: 'session',
            event: 'prepare_failed',
            module: module.appName,
            requestKey: moduleKey,
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: 'error',
            reason: reason.name,
            extra: <String, dynamic>{'source': source, 'message': e.toString()},
          ),
        );
        rethrow;
      } finally {
        _studentTasks.remove(moduleKey);
      }
    }();

    _studentTasks[moduleKey] = task;
    await task;
  }

  Future<void> ensureStudentReady(
    XgModule module, {
    String source = 'page',
  }) async {
    await prepareStudentModule(module, source: source);
  }

  Future<T> runWithStudentSession<T>(
    XgModule module,
    Future<T> Function() action, {
    String source = 'student_action',
  }) async {
    await ensureStudentReady(module, source: source);
    return action();
  }

  /// 预加载智慧学工基础会话（不再依赖功能权限列表）
  Future<bool> preloadAvailableModules({String source = 'home_preload'}) async {
    final username = await _store.getUsername();
    if (username == null || username.isEmpty) {
      return false;
    }
    final accessToken = await _store.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }
    final preloadKey = '$username:$source';
    final existing = _preloadTasks[preloadKey];
    if (existing != null) {
      await _traceSession(
        XgTraceLogEntry(
          phase: 'preload',
          event: 'coordinator_preload_reused',
          module: 'multi',
          requestKey: preloadKey,
          result: 'reused',
        ),
      );
      return existing;
    }

    final task = () async {
      final stopwatch = Stopwatch()..start();
      try {
        await _traceSession(
          XgTraceLogEntry(
            phase: 'preload',
            event: 'coordinator_preload_started',
            module: 'multi',
            requestKey: preloadKey,
            result: 'started',
            extra: <String, dynamic>{'source': source},
          ),
        );

        await _ensureBaseSessionTask(
          username: username,
          accessToken: accessToken,
          source: source,
        );
        await _traceSession(
          XgTraceLogEntry(
            phase: 'preload',
            event: 'coordinator_preload_finished',
            module: 'multi',
            requestKey: preloadKey,
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: 'ok',
            extra: <String, dynamic>{
              'source': source,
              'mode': 'base_session_only',
              'preloaded': true,
            },
          ),
        );
        return true;
      } catch (e) {
        await _traceSession(
          XgTraceLogEntry(
            phase: 'preload',
            event: 'coordinator_preload_failed',
            module: 'multi',
            requestKey: preloadKey,
            elapsedMs: stopwatch.elapsedMilliseconds,
            result: 'error',
            reason: e.runtimeType.toString(),
            extra: <String, dynamic>{'source': source, 'message': e.toString()},
          ),
        );
        rethrow;
      } finally {
        _preloadTasks.remove(preloadKey);
      }
    }();

    _preloadTasks[preloadKey] = task;
    return task;
  }

  Future<void> clearCurrentUserModules() async {
    _studentTasks.clear();
    _baseSessionTasks.clear();
    _preloadTasks.clear();
    await _store.clearAllXgSessionSnapshots();
  }
}
