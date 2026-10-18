/// 融合门户公告数据模型
class PortalAnnouncement {
  final String id; // 公告唯一ID (从URL中提取)
  final String category; // 公告分类，如"学生公告"
  final String title; // 公告标题
  final String department; // 发布部门
  final String publishDate; // 发布日期，格式如 "2025-12-17 10:25"
  final int viewCount; // 浏览次数
  final String detailUrl; // 详情页面URL

  PortalAnnouncement({
    required this.id,
    required this.category,
    required this.title,
    required this.department,
    required this.publishDate,
    required this.viewCount,
    required this.detailUrl,
  });

  /// 从JSON构造
  factory PortalAnnouncement.fromJson(Map<String, dynamic> json) {
    return PortalAnnouncement(
      id: json['id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      department: json['department'] as String,
      publishDate: json['publish_date'] as String,
      viewCount: json['view_count'] as int? ?? 0,
      detailUrl: json['detail_url'] as String,
    );
  }

  /// 转为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'department': department,
      'publish_date': publishDate,
      'view_count': viewCount,
      'detail_url': detailUrl,
    };
  }

  /// 获取格式化的日期（仅日期部分）
  String get formattedDate {
    try {
      final parts = publishDate.split(' ');
      return parts.isNotEmpty ? parts[0] : publishDate;
    } catch (e) {
      return publishDate;
    }
  }

  /// 获取格式化的时间（仅时间部分）
  String get formattedTime {
    try {
      final parts = publishDate.split(' ');
      return parts.length > 1 ? parts[1] : '';
    } catch (e) {
      return '';
    }
  }
}
