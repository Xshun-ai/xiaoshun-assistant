/// 智慧学工活动模型
class XgActivity {
  /// 活动唯一ID (HDDM)
  final String id;

  /// 活动名称 (HDMC)
  final String name;

  /// 活动地点 (HDDD_DISPLAY)
  final String location;

  /// 活动时间描述 (HDKSSJ)
  final String timeDescription;

  /// 活动级别 (HDJBDM_DISPLAY)
  final String level;

  /// 已报名人数 (BMRS)
  final int appliedCount;

  /// 人数限制 (HDRSXZ)
  final int? limitCount;

  /// 是否可报名 (CANAPPLY)
  final bool canApply;

  /// 报名开始时间 (HDBMKSSJ)
  final String startTime;

  /// 报名结束时间 (HDBMJSSJ)
  final String endTime;

  /// 审核状态代码 (SHZT)
  final String? status;

  /// 审核状态显示名 (SHZT_DISPLAY)
  final String? statusDisplay;

  XgActivity({
    required this.id,
    required this.name,
    required this.location,
    required this.timeDescription,
    required this.level,
    required this.appliedCount,
    this.limitCount,
    required this.canApply,
    required this.startTime,
    required this.endTime,
    this.status,
    this.statusDisplay,
  });

  /// 解析后的结束时间
  DateTime? get parsedEndTime {
    try {
      if (endTime.isEmpty) return null;
      String cleanTime = endTime.replaceAll('/', '-');
      return DateTime.tryParse(cleanTime);
    } catch (e) {
      return null;
    }
  }

  /// 是否已过期
  bool get isExpired {
    final end = parsedEndTime;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  /// 是否已满员
  bool get isFull {
    if (limitCount == null) return false;
    return appliedCount >= limitCount!;
  }

  /// 实际是否可报名 (结合服务器状态、过期状态和满员状态)
  bool get effectiveCanApply {
    // 如果服务器说不可报名，那就是不可报名
    if (!canApply) return false;
    // 如果已过期，不可报名
    if (isExpired) return false;
    // 如果已满员，不可报名
    if (isFull) return false;
    return true;
  }

  factory XgActivity.fromJson(Map<String, dynamic> json) {
    return XgActivity(
      id: json['HDDM'] ?? '',
      name: json['HDMC'] ?? '',
      location: json['HDDD_DISPLAY'] ?? '未知地点',
      timeDescription: json['HDKSSJ'] ?? '',
      level: json['HDJBDM_DISPLAY'] ?? '未知级别',
      appliedCount: int.tryParse(json['BMRS']?.toString() ?? '0') ?? 0,
      limitCount: json['HDRSXZ'] != null
          ? int.tryParse(json['HDRSXZ'].toString())
          : null,
      canApply: json['CANAPPLY'] == 'true' || json['CANAPPLY'] == true,
      startTime: json['HDBMKSSJ'] ?? '',
      endTime: json['HDBMJSSJ'] ?? '',
      status: json['SHZT'],
      statusDisplay: json['SHZT_DISPLAY'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'HDDM': id,
      'HDMC': name,
      'HDDD_DISPLAY': location,
      'HDKSSJ': timeDescription,
      'HDJBDM_DISPLAY': level,
      'BMRS': appliedCount,
      'HDRSXZ': limitCount,
      'CANAPPLY': canApply,
      'HDBMKSSJ': startTime,
      'HDBMJSSJ': endTime,
      'SHZT': status,
      'SHZT_DISPLAY': statusDisplay,
    };
  }
}
