class UserInfo {
  final String displayName;
  final String username; // Student ID
  final String ouName; // Department
  final String className; // bjmc
  final String major; // zymc
  final String status; // XJZT

  UserInfo({
    required this.displayName,
    required this.username,
    required this.ouName,
    required this.className,
    required this.major,
    required this.status,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final account = data['udAccountInformation'] ?? {};
    final dict = data['dataDictionaryValues'] ?? {};

    return UserInfo(
      displayName: account['displayName'] ?? '未知用户',
      username: account['username'] ?? '',
      ouName: account['ouName'] ?? '',
      className: dict['bjmc'] ?? '',
      major: dict['zymc'] ?? '',
      status: dict['XJZT'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'username': username,
      'ouName': ouName,
      'className': className,
      'major': major,
      'status': status,
    };
  }

  factory UserInfo.fromCache(Map<String, dynamic> json) {
    return UserInfo(
      displayName: json['displayName'] ?? '',
      username: json['username'] ?? '',
      ouName: json['ouName'] ?? '',
      className: json['className'] ?? '',
      major: json['major'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
