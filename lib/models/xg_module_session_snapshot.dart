enum XgModuleSessionState {
  idle,
  preparing,
  ready,
  stale,
  recovering,
  failed,
}

enum XgSessionStaleReason {
  forcedRefresh,
  http302,
  http403,
  loginHtml,
  timeout,
  crossUserMismatch,
  manual,
  schoolTokenRecovered,
  unknown,
}

class XgModuleSessionSnapshot {
  final String appName;
  final String username;
  final String currentRoleId;
  final DateTime? preparedAt;
  final DateTime? warmUpVerifiedAt;
  final DateTime? lastReadyAt;
  final DateTime? lastFailureAt;
  final XgModuleSessionState state;
  final XgSessionStaleReason? lastFailureReason;
  final int snapshotVersion;

  const XgModuleSessionSnapshot({
    required this.appName,
    required this.username,
    required this.currentRoleId,
    required this.state,
    required this.snapshotVersion,
    this.preparedAt,
    this.warmUpVerifiedAt,
    this.lastReadyAt,
    this.lastFailureAt,
    this.lastFailureReason,
  });

  factory XgModuleSessionSnapshot.fromJson(Map<String, dynamic> json) {
    XgModuleSessionState parseState(String? raw) {
      return XgModuleSessionState.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => XgModuleSessionState.idle,
      );
    }

    XgSessionStaleReason? parseReason(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return XgSessionStaleReason.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => XgSessionStaleReason.unknown,
      );
    }

    DateTime? parseTime(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return XgModuleSessionSnapshot(
      appName: json['appName']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      currentRoleId: json['currentRoleId']?.toString() ?? '',
      preparedAt: parseTime(json['preparedAt']),
      warmUpVerifiedAt: parseTime(json['warmUpVerifiedAt']),
      lastReadyAt: parseTime(json['lastReadyAt']),
      lastFailureAt: parseTime(json['lastFailureAt']),
      state: parseState(json['state']?.toString()),
      lastFailureReason: parseReason(json['lastFailureReason']?.toString()),
      snapshotVersion:
          int.tryParse(json['snapshotVersion']?.toString() ?? '') ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'username': username,
      'currentRoleId': currentRoleId,
      'preparedAt': preparedAt?.toUtc().toIso8601String(),
      'warmUpVerifiedAt': warmUpVerifiedAt?.toUtc().toIso8601String(),
      'lastReadyAt': lastReadyAt?.toUtc().toIso8601String(),
      'lastFailureAt': lastFailureAt?.toUtc().toIso8601String(),
      'state': state.name,
      'lastFailureReason': lastFailureReason?.name,
      'snapshotVersion': snapshotVersion,
    };
  }

  XgModuleSessionSnapshot copyWith({
    String? appName,
    String? username,
    String? currentRoleId,
    DateTime? preparedAt,
    DateTime? warmUpVerifiedAt,
    DateTime? lastReadyAt,
    DateTime? lastFailureAt,
    XgModuleSessionState? state,
    XgSessionStaleReason? lastFailureReason,
    bool clearLastFailureReason = false,
    int? snapshotVersion,
  }) {
    return XgModuleSessionSnapshot(
      appName: appName ?? this.appName,
      username: username ?? this.username,
      currentRoleId: currentRoleId ?? this.currentRoleId,
      preparedAt: preparedAt ?? this.preparedAt,
      warmUpVerifiedAt: warmUpVerifiedAt ?? this.warmUpVerifiedAt,
      lastReadyAt: lastReadyAt ?? this.lastReadyAt,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
      state: state ?? this.state,
      lastFailureReason: clearLastFailureReason
          ? null
          : (lastFailureReason ?? this.lastFailureReason),
      snapshotVersion: snapshotVersion ?? this.snapshotVersion,
    );
  }
}
