/// 校园地图数据模型
///
/// 包含 MapCategory（分类标签）和 CampusMarker（地图标注点）
library;

/// 地图标注分类
class MapCategory {
  final int id;
  final String name;
  final String icon; // Material Icons 名称

  const MapCategory({required this.id, required this.name, required this.icon});

  factory MapCategory.fromJson(Map<String, dynamic> json) {
    return MapCategory(
      id: int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'place',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': icon};
}

/// 地图标注点
class CampusMarker {
  final int id;
  final int lid; // 分类 ID（对应 MapCategory.id）
  final String title;
  final double latitude;
  final double longitude;
  final String markerSource;

  const CampusMarker({
    required this.id,
    required this.lid,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.markerSource = 'official',
  });

  factory CampusMarker.fromJson(Map<String, dynamic> json) {
    return CampusMarker(
      id: int.tryParse('${json['id']}') ?? 0,
      lid: int.tryParse('${json['lid']}') ?? 0,
      title: json['title']?.toString() ?? '',
      latitude: double.tryParse('${json['latitude']}') ?? 0.0,
      longitude: double.tryParse('${json['longitude']}') ?? 0.0,
      markerSource: json['marker_source']?.toString() ?? 'official',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lid': lid,
    'title': title,
    'latitude': latitude,
    'longitude': longitude,
    'marker_source': markerSource,
  };
}

class CampusMapContent {
  final DateTime? updatedAt;
  final List<MapCategory> categories;
  final List<CampusMarker> markers;

  const CampusMapContent({
    required this.updatedAt,
    required this.categories,
    required this.markers,
  });

  const CampusMapContent.empty()
    : updatedAt = null,
      categories = const [],
      markers = const [];

  factory CampusMapContent.fromJson(Map<String, dynamic> json) {
    final categoryList = (json['categories'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => MapCategory.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final markerList = (json['markers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => CampusMarker.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return CampusMapContent(
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      categories: categoryList,
      markers: markerList,
    );
  }
}

/// 用户提交的标注点记录
class CampusMapSubmission {
  final int id;
  final int categoryId;
  final String title;
  final double latitude;
  final double longitude;
  final String reviewStatus;
  final String submitterRemark;
  final String? reviewRemark;
  final String? reviewedAt;
  final String createdAt;

  const CampusMapSubmission({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.reviewStatus,
    required this.submitterRemark,
    this.reviewRemark,
    this.reviewedAt,
    required this.createdAt,
  });

  factory CampusMapSubmission.fromJson(Map<String, dynamic> json) {
    return CampusMapSubmission(
      id: int.tryParse('${json['id']}') ?? 0,
      categoryId: int.tryParse('${json['category_id']}') ?? 0,
      title: json['title']?.toString() ?? '',
      latitude: double.tryParse('${json['latitude']}') ?? 0.0,
      longitude: double.tryParse('${json['longitude']}') ?? 0.0,
      reviewStatus: json['review_status']?.toString() ?? 'pending',
      submitterRemark: json['submitter_remark']?.toString() ?? '',
      reviewRemark: json['review_remark']?.toString(),
      reviewedAt: json['reviewed_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  String get reviewStatusLabel {
    switch (reviewStatus) {
      case 'pending':
        return '待审核';
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已拒绝';
      default:
        return reviewStatus;
    }
  }
}
