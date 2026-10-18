import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/xg_module_session_snapshot.dart';

typedef XgScopedStringSetter = Future<void> Function(
  SharedPreferences prefs,
  String baseKey,
  String value,
);
typedef XgScopedStringGetter = Future<String?> Function(
  SharedPreferences prefs,
  String baseKey,
);
typedef XgScopedPrefixRemover = Future<void> Function(
  SharedPreferences prefs,
  String prefix,
);

class XgCacheStore {
  final XgScopedStringSetter _setScopedString;
  final XgScopedStringGetter _getScopedString;
  final XgScopedPrefixRemover _removeKeysWithPrefix;
  final String _xgSessionUserKey;
  final String _xgSessionSnapshotKey;
  final String _xgSessionRoleKey;
  final String _xgSessionGroupRefreshedAtKey;
  final String _xgModuleSnapshotKey;
  final String _xgActivityListCacheKey;
  final String _xgEvaluationOverviewCacheKey;

  XgCacheStore({
    required XgScopedStringSetter setScopedString,
    required XgScopedStringGetter getScopedString,
    required XgScopedPrefixRemover removeKeysWithPrefix,
    required String xgSessionUserKey,
    required String xgSessionSnapshotKey,
    required String xgSessionRoleKey,
    required String xgSessionGroupRefreshedAtKey,
    required String xgModuleSnapshotKey,
    required String xgActivityListCacheKey,
    required String xgEvaluationOverviewCacheKey,
  }) : _setScopedString = setScopedString,
       _getScopedString = getScopedString,
       _removeKeysWithPrefix = removeKeysWithPrefix,
       _xgSessionUserKey = xgSessionUserKey,
       _xgSessionSnapshotKey = xgSessionSnapshotKey,
       _xgSessionRoleKey = xgSessionRoleKey,
       _xgSessionGroupRefreshedAtKey = xgSessionGroupRefreshedAtKey,
       _xgModuleSnapshotKey = xgModuleSnapshotKey,
       _xgActivityListCacheKey = xgActivityListCacheKey,
       _xgEvaluationOverviewCacheKey = xgEvaluationOverviewCacheKey;

  Future<void> saveXgSessionUser(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_xgSessionUserKey, username);
    } catch (_) {}
  }

  Future<String?> getXgSessionUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_xgSessionUserKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLegacyXgSessionArtifacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _removeKeysWithPrefix(prefs, _xgSessionSnapshotKey);
      await _removeKeysWithPrefix(prefs, _xgSessionRoleKey);
      await _removeKeysWithPrefix(prefs, _xgSessionGroupRefreshedAtKey);
    } catch (_) {}
  }

  Future<void> clearAllXgSessionSnapshots() async {
    await clearLegacyXgSessionArtifacts();
    try {
      final prefs = await SharedPreferences.getInstance();
      await _removeKeysWithPrefix(prefs, _xgModuleSnapshotKey);
    } catch (_) {}
  }

  String _buildModuleSnapshotKey(String appName) {
    return '$_xgModuleSnapshotKey:$appName';
  }

  Future<void> saveXgModuleSnapshot(XgModuleSessionSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await _setScopedString(
      prefs,
      _buildModuleSnapshotKey(snapshot.appName),
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<XgModuleSessionSnapshot?> getXgModuleSnapshot(String appName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _getScopedString(prefs, _buildModuleSnapshotKey(appName));
    if (raw == null || raw.isEmpty) return null;
    try {
      return XgModuleSessionSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearXgModuleSnapshot(String appName) async {
    final prefs = await SharedPreferences.getInstance();
    await _removeKeysWithPrefix(prefs, _buildModuleSnapshotKey(appName));
  }

  Future<void> saveXgActivityListCache(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await _setScopedString(prefs, _xgActivityListCacheKey, json);
  }

  Future<String?> getXgActivityListCache() async {
    final prefs = await SharedPreferences.getInstance();
    return _getScopedString(prefs, _xgActivityListCacheKey);
  }

  Future<void> clearXgActivityListCache() async {
    final prefs = await SharedPreferences.getInstance();
    await _removeKeysWithPrefix(prefs, _xgActivityListCacheKey);
  }

  Future<void> saveXgEvaluationOverviewCache(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await _setScopedString(prefs, _xgEvaluationOverviewCacheKey, json);
  }

  Future<String?> getXgEvaluationOverviewCache() async {
    final prefs = await SharedPreferences.getInstance();
    return _getScopedString(prefs, _xgEvaluationOverviewCacheKey);
  }

  Future<void> clearXgEvaluationOverviewCache() async {
    final prefs = await SharedPreferences.getInstance();
    await _removeKeysWithPrefix(prefs, _xgEvaluationOverviewCacheKey);
  }
}
