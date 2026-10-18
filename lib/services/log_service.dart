import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'session_store.dart';

class XgTraceLogEntry {
  final String phase;
  final String event;
  final String? module;
  final String? page;
  final String? requestKey;
  final int? elapsedMs;
  final String result;
  final String? reason;
  final Map<String, dynamic>? extra;

  const XgTraceLogEntry({
    required this.phase,
    required this.event,
    this.module,
    this.page,
    this.requestKey,
    this.elapsedMs,
    this.result = 'ok',
    this.reason,
    this.extra,
  });
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final SessionStore _sessionStore = SessionStore();
  static const String _logFileName = 'app_runtime.log';
  static const String _logDirectoryName = 'runtime_logs';
  static const String _dailyLogPrefix = 'app_runtime_';
  static const String _dailyLogSuffix = '.log';

  String? _lastCleanupDay;
  Future<void>? _cleanupFuture;
  Future<void> _localLogWriteQueue = Future<void>.value();

  String _buildXgTraceId() {
    final now = DateTime.now().toUtc();
    final micros = now.microsecondsSinceEpoch.toString();
    return 'xg-${micros.substring(micros.length - 10)}';
  }

  /// 获取日志文件路径
  Future<File> getLogFile() async {
    final directory = await _getLogDirectory();
    final today = _formatDay(DateTime.now());
    return File('${directory.path}/$_dailyLogPrefix$today$_dailyLogSuffix');
  }

  Future<File> _getLegacyLogFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_logFileName');
  }

  Future<Directory> _getLogDirectory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/$_logDirectoryName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _formatDay(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _maybeCleanup() async {
    final today = _formatDay(DateTime.now());
    if (_lastCleanupDay == today) return;

    _cleanupFuture ??= _cleanupOldLogs(keepDays: 7).whenComplete(() {
      _lastCleanupDay = today;
      _cleanupFuture = null;
    });

    return _cleanupFuture;
  }

  Future<void> _cleanupOldLogs({required int keepDays}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final cutoffDay = todayStart.subtract(Duration(days: keepDays));

    try {
      final directory = await _getLogDirectory();
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isEmpty
            ? ''
            : entity.uri.pathSegments.last;
        if (!name.startsWith(_dailyLogPrefix) ||
            !name.endsWith(_dailyLogSuffix)) {
          continue;
        }

        final dayText = name.substring(
          _dailyLogPrefix.length,
          name.length - _dailyLogSuffix.length,
        );
        DateTime? day;
        try {
          day = DateTime.parse(dayText);
        } catch (_) {
          day = null;
        }
        if (day == null) {
          continue;
        }
        final dayStart = DateTime(day.year, day.month, day.day);
        if (dayStart.isBefore(cutoffDay)) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('清理日志文件失败: $e');
    }

    try {
      final legacyFile = await _getLegacyLogFile();
      if (!await legacyFile.exists()) {
        return;
      }

      final content = await _readTextAllowMalformed(legacyFile);
      final lines = content.split('\n');
      final cutoffTime = DateTime.now().subtract(Duration(days: keepDays));

      final kept = <String>[];
      for (final line in lines) {
        if (line.isEmpty) continue;
        final timestamp = _extractTimestampFromLogLine(line);
        if (timestamp != null && timestamp.isAfter(cutoffTime)) {
          kept.add(line);
        }
      }

      await legacyFile.writeAsString(
        kept.join('\n') + (kept.isEmpty ? '' : '\n'),
      );
    } catch (e) {
      debugPrint('清理旧版日志文件失败: $e');
    }
  }

  Future<String> _readTextAllowMalformed(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('读取文件内容失败: $e');
      return '';
    }
  }

  /// 获取最近日志内容，默认保留范围为 7 天。
  Future<String> getRecentLogs({int days = 7}) async {
    await _maybeCleanup();
    try {
      final cutoffTime = DateTime.now().subtract(Duration(days: days));
      final recentLines = <String>[];

      final directory = await _getLogDirectory();

      final now = DateTime.now();
      for (int i = days - 1; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayText = _formatDay(day);
        final file = File(
          '${directory.path}/$_dailyLogPrefix$dayText$_dailyLogSuffix',
        );
        if (!await file.exists()) continue;

        final content = await _readTextAllowMalformed(file);
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.isEmpty) continue;
          final timestamp = _extractTimestampFromLogLine(line);
          if (timestamp != null && timestamp.isAfter(cutoffTime)) {
            recentLines.add(line);
          }
        }
      }

      final legacyFile = await _getLegacyLogFile();
      if (await legacyFile.exists()) {
        final content = await _readTextAllowMalformed(legacyFile);
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.isEmpty) continue;
          final timestamp = _extractTimestampFromLogLine(line);
          if (timestamp != null && timestamp.isAfter(cutoffTime)) {
            recentLines.add(line);
          }
        }
      }

      return recentLines.join('\n');
    } catch (e) {
      debugPrint('读取最近日志失败: $e');
      return '';
    }
  }

  Future<void> clearLogs() async {
    try {
      final directory = await _getLogDirectory();
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      final legacyFile = await _getLegacyLogFile();
      if (await legacyFile.exists()) {
        await legacyFile.delete();
      }
    } catch (e) {
      debugPrint('清理日志文件失败: $e');
    }
  }

  /// 从日志行中提取时间戳
  DateTime? _extractTimestampFromLogLine(String logLine) {
    try {
      // 日志格式为 [timestamp] content
      if (logLine.startsWith('[') && logLine.contains(']')) {
        final endBracketIndex = logLine.indexOf(']');
        final timestampStr = logLine.substring(1, endBracketIndex);
        return DateTime.parse(timestampStr);
      }
    } catch (e) {
      debugPrint('解析日志时间戳失败: $e');
      // 如果解析失败，返回null
    }
    return null;
  }

  /// 写入本地日志
  Future<void> _writeToLocalLog(String content) {
    // 同时输出到控制台，方便调试
    debugPrint(content);
    final task = _localLogWriteQueue.then<void>((_) async {
      try {
        await _maybeCleanup();
        final file = await getLogFile();
        final timestamp = DateTime.now().toIso8601String();
        await file.writeAsString(
          '[$timestamp] $content\n',
          mode: FileMode.append,
        );
      } catch (e) {
        debugPrint('写入本地日志失败: $e');
      }
    });
    _localLogWriteQueue = task;
    return task;
  }

  /// 记录普通运行日志。
  Future<void> logRuntime(String message) async {
    await _writeToLocalLog(message);
  }

  String _sanitizeTraceValue(String value) {
    return value
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('|', '/')
        .trim();
  }

  String _sanitizeTraceUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    try {
      final uri = Uri.parse(url);
      final path = uri.path.isEmpty ? '/' : uri.path;
      return '${uri.scheme}://${uri.host}$path';
    } catch (_) {
      return _sanitizeTraceValue(url);
    }
  }

  String sanitizeSensitiveUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    try {
      final uri = Uri.parse(url);
      final filtered = _sanitizeUrlParameters(uri.queryParameters);
      final withoutFragment = uri
          .replace(
            queryParameters: filtered.isEmpty ? null : filtered,
            fragment: '',
          )
          .toString()
          .replaceFirst(RegExp(r'#$'), '');
      if (uri.fragment.isEmpty) return withoutFragment;
      return '$withoutFragment#${_sanitizeUrlFragment(uri.fragment)}';
    } catch (_) {
      return _sanitizeUrlText(url);
    }
  }

  Map<String, String> _sanitizeUrlParameters(Map<String, String> parameters) {
    return <String, String>{
      for (final entry in parameters.entries)
        entry.key: _isSensitiveUrlParameter(entry.key) ? '***' : entry.value,
    };
  }

  String _sanitizeUrlFragment(String fragment) {
    if (fragment.isEmpty) return fragment;
    return _sanitizeUrlText(fragment);
  }

  bool _isSensitiveUrlParameter(String key) {
    final normalized = key.toLowerCase();
    return normalized == 'access_token' ||
        normalized == 'ticket' ||
        normalized == 'linkeduuid' ||
        normalized == 'token';
  }

  String _sanitizeUrlText(String value) {
    return value.replaceAllMapped(
      RegExp(
        r'((?:access_token|ticket|linkedUuid|token)=)[^&#\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}***',
    );
  }

  Future<String> ensureXgTraceId() async {
    final existing = await _sessionStore.getXgTraceCurrentId();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final traceId = _buildXgTraceId();
    await _sessionStore.saveXgTraceCurrentId(traceId);
    await _sessionStore.saveXgTraceStartedAt(DateTime.now().toUtc());
    return traceId;
  }

  Future<void> resetXgTraceSession() async {
    final traceId = _buildXgTraceId();
    final startedAt = DateTime.now().toUtc();
    await _sessionStore.saveXgTraceCurrentId(traceId);
    await _sessionStore.saveXgTraceStartedAt(startedAt);
    await _writeToLocalLog(
      'XG_TRACE|traceId=$traceId|phase=session|event=start|module=-|page=-|requestKey=-|elapsedMs=-|result=started|reason=-|extra=${jsonEncode({'startedAt': startedAt.toIso8601String()})}',
    );
  }

  Future<void> logXgTrace(XgTraceLogEntry entry, {String? traceId}) async {
    final effectiveTraceId = traceId ?? await ensureXgTraceId();
    final payload = <String, String>{
      'traceId': _sanitizeTraceValue(effectiveTraceId),
      'phase': _sanitizeTraceValue(entry.phase),
      'event': _sanitizeTraceValue(entry.event),
      'module': _sanitizeTraceValue(entry.module ?? '-'),
      'page': _sanitizeTraceValue(entry.page ?? '-'),
      'requestKey': _sanitizeTraceValue(entry.requestKey ?? '-'),
      'elapsedMs': entry.elapsedMs?.toString() ?? '-',
      'result': _sanitizeTraceValue(entry.result),
      'reason': _sanitizeTraceValue(entry.reason ?? '-'),
      'extra': entry.extra == null ? '{}' : jsonEncode(entry.extra),
    };

    await _writeToLocalLog(
      'XG_TRACE|traceId=${payload['traceId']}|phase=${payload['phase']}|event=${payload['event']}|module=${payload['module']}|page=${payload['page']}|requestKey=${payload['requestKey']}|elapsedMs=${payload['elapsedMs']}|result=${payload['result']}|reason=${payload['reason']}|extra=${payload['extra']}',
    );
  }

  String summarizeTraceUrl(String? url) {
    return _sanitizeTraceUrl(url);
  }

  /// 记录本地日志。
  Future<void> log(String action, String details) async {
    try {
      await _writeToLocalLog('操作: $action, 详情: $details');
    } catch (e) {
      debugPrint('日志服务异常: $e');
    }
  }
}
