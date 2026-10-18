class XgEvaluationSemester {
  final String cpxn; // 学年代码
  final String cpxnDisplay; // 学年显示名
  final String cpxq; // 学期代码
  final String cpxqDisplay; // 学期显示名
  final String? pcdm; // 批次代码 (Assumed to be present based on requirement to query score)

  XgEvaluationSemester({
    required this.cpxn,
    required this.cpxnDisplay,
    required this.cpxq,
    required this.cpxqDisplay,
    this.pcdm,
  });

  factory XgEvaluationSemester.fromJson(Map<String, dynamic> json) {
    return XgEvaluationSemester(
      cpxn: json['CPXN']?.toString() ?? '',
      cpxnDisplay: json['CPXN_DISPLAY']?.toString() ?? '',
      cpxq: json['CPXQ']?.toString() ?? '',
      cpxqDisplay: json['CPXQ_DISPLAY']?.toString() ?? '',
      pcdm: json['PCDM']?.toString(),
    );
  }

  String get displayName => '$cpxnDisplay $cpxqDisplay';

  Map<String, dynamic> toJson() {
    return {
      'CPXN': cpxn,
      'CPXN_DISPLAY': cpxnDisplay,
      'CPXQ': cpxq,
      'CPXQ_DISPLAY': cpxqDisplay,
      'PCDM': pcdm,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is XgEvaluationSemester &&
        other.cpxn == cpxn &&
        other.cpxq == cpxq &&
        other.pcdm == pcdm;
  }

  @override
  int get hashCode => Object.hash(cpxn, cpxq, pcdm);
}
