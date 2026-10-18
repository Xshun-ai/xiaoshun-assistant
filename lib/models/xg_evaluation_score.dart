/// 综合评测成绩摘要。
///
/// 包含总分、班级排名和专业排名。
class XgEvaluationScore {
  final String xsbh;
  final String xm;
  final String dwdmDisplay;
  final String zydm;
  final String zydmDisplay;
  final String bjdm;
  final String bjdmDisplay;
  final String xznj;
  final String cpxnDisplay;
  final String cpxqDisplay;
  final double zcj;
  final String bjpm;
  final String zynjpm;

  XgEvaluationScore({
    required this.xsbh,
    required this.xm,
    required this.dwdmDisplay,
    required this.zydm,
    required this.zydmDisplay,
    required this.bjdm,
    required this.bjdmDisplay,
    required this.xznj,
    required this.cpxnDisplay,
    required this.cpxqDisplay,
    required this.zcj,
    required this.bjpm,
    required this.zynjpm,
  });

  factory XgEvaluationScore.fromJson(Map<String, dynamic> json) {
    return XgEvaluationScore(
      xsbh: json['XSBH']?.toString() ?? json['XH']?.toString() ?? '',
      xm: json['XM']?.toString() ?? '',
      dwdmDisplay: json['DWDM_DISPLAY']?.toString() ?? '',
      zydm: json['ZYDM']?.toString() ?? '',
      zydmDisplay: json['ZYDM_DISPLAY']?.toString() ?? '',
      bjdm: json['BJDM']?.toString() ?? '',
      bjdmDisplay: json['BJDM_DISPLAY']?.toString() ?? '',
      xznj: json['XZNJ']?.toString() ?? '',
      cpxnDisplay: json['CPXN_DISPLAY']?.toString() ?? '',
      cpxqDisplay: json['CPXQ_DISPLAY']?.toString() ?? '',
      zcj: double.tryParse(json['ZCJ']?.toString() ?? '0') ?? 0.0,
      bjpm: json['BJPM']?.toString() ?? '-',
      zynjpm: json['ZYNJPM']?.toString() ?? '-',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'XSBH': xsbh,
      'XM': xm,
      'DWDM_DISPLAY': dwdmDisplay,
      'ZYDM': zydm,
      'ZYDM_DISPLAY': zydmDisplay,
      'BJDM': bjdm,
      'BJDM_DISPLAY': bjdmDisplay,
      'XZNJ': xznj,
      'CPXN_DISPLAY': cpxnDisplay,
      'CPXQ_DISPLAY': cpxqDisplay,
      'ZCJ': zcj,
      'BJPM': bjpm,
      'ZYNJPM': zynjpm,
    };
  }
}
