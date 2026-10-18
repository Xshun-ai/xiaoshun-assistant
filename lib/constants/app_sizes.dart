/// 应用尺寸常量
/// 统一管理整个应用的间距、圆角等尺寸规范
class AppSizes {
  // 私有构造函数，防止实例化
  AppSizes._();

  // ==================== 边距/内边距 ====================
  /// 极小间距 4px
  static const double paddingTiny = 4.0;

  /// 小间距 8px
  static const double paddingSmall = 8.0;

  /// 中等间距 12px
  static const double paddingMedium = 12.0;

  /// 默认间距 16px
  static const double paddingDefault = 16.0;

  /// 大间距 20px
  static const double paddingLarge = 20.0;

  /// 超大间距 24px
  static const double paddingXLarge = 24.0;

  /// 巨大间距 32px
  static const double paddingHuge = 32.0;

  // ==================== 圆角 ====================
  /// 小圆角 4px
  static const double radiusSmall = 4.0;

  /// 中等圆角 8px
  static const double radiusMedium = 8.0;

  /// 默认圆角 12px
  static const double radiusDefault = 12.0;

  /// 大圆角 16px
  static const double radiusLarge = 16.0;

  /// 超大圆角 20px
  static const double radiusXLarge = 20.0;

  /// 巨大圆角 24px
  static const double radiusHuge = 24.0;

  /// 圆形 999px
  static const double radiusCircle = 999.0;

  // ==================== 图标尺寸 ====================
  /// 小图标 16px
  static const double iconSmall = 16.0;

  /// 默认图标 24px
  static const double iconDefault = 24.0;

  /// 大图标 32px
  static const double iconLarge = 32.0;

  /// 超大图标 48px
  static const double iconXLarge = 48.0;

  // ==================== 按钮高度 ====================
  /// 小按钮高度 32px
  static const double buttonSmall = 32.0;

  /// 默认按钮高度 44px
  static const double buttonDefault = 44.0;

  /// 大按钮高度 50px
  static const double buttonLarge = 50.0;

  // ==================== 阴影 ====================
  /// 默认阴影模糊半径
  static const double shadowBlur = 10.0;

  /// 默认阴影偏移
  static const double shadowOffset = 4.0;

  // ==================== 课程表专用尺寸 ====================
  /// 课程表左侧列宽度
  static const double scheduleLeftColumnWidth = 35.0;

  /// 课程表表头高度
  static const double scheduleHeaderHeight = 40.0;

  /// 课程表最小列宽
  static const double scheduleMinColumnWidth = 46.0;

  /// 课程表最小行高
  static const double scheduleMinCellHeight = 80.0;
}
