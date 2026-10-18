/// 智慧学工活动申请记录模型
class XgActivityRecord {
  /// 学生编号 (XSBH)
  final String studentId;

  /// 活动唯一ID (HDDM)
  final String activityId;

  /// 活动名称 (HDMC)
  final String activityName;

  /// 活动类型代码 (HDLXDM)
  final String typeCode;

  /// 活动类型显示名 (HDLXDM_DISPLAY)
  final String typeDisplay;

  /// 申请时间 (SQSJ)
  final String applyTime;

  /// 申请陈述 (SQCS)
  final String applyStatement;

  /// 审核状态代码 (SHZT)
  final String auditStatus;

  /// 审核状态显示名 (SHZT_DISPLAY)
  final String auditStatusDisplay;

  /// 审核意见 (SHYJ)
  final String auditOpinion;

  /// 活动是否结束 (ISFINISH)
  final bool isFinished;

  /// 活动评分 (HDPF)
  final String? score;

  XgActivityRecord({
    required this.studentId,
    required this.activityId,
    required this.activityName,
    required this.typeCode,
    required this.typeDisplay,
    required this.applyTime,
    required this.applyStatement,
    required this.auditStatus,
    required this.auditStatusDisplay,
    required this.auditOpinion,
    required this.isFinished,
    this.score,
  });

  factory XgActivityRecord.fromJson(Map<String, dynamic> json) {
    return XgActivityRecord(
      studentId: json['XSBH'] ?? '',
      activityId: json['HDDM'] ?? '',
      activityName: json['HDMC'] ?? '',
      typeCode: json['HDLXDM'] ?? '',
      typeDisplay: json['HDLXDM_DISPLAY'] ?? '无',
      applyTime: json['SQSJ'] ?? '',
      applyStatement: json['SQCS'] ?? '',
      auditStatus: json['SHZT'] ?? '',
      auditStatusDisplay: json['SHZT_DISPLAY'] ?? '',
      auditOpinion: json['SHYJ'] ?? '',
      isFinished: json['ISFINISH'] == 'true' || json['ISFINISH'] == true,
      score: json['HDPF'],
    );
  }

  // 综合状态描述
  String get statusText {
    if (isFinished) return '已结束';
    return auditStatusDisplay;
  }
}
