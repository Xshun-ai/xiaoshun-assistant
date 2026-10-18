import 'package:flutter/material.dart';

/// 应用颜色常量
/// 统一管理整个应用的配色方案
class AppColors {
  // 私有构造函数，防止实例化
  AppColors._();

  // ==================== 主题色 ====================
  /// 主色调 - 道奇蓝
  static const Color primary = Color(0xFF1E90FF);

  /// 苹果蓝 - iOS风格主色（智慧学工专用）
  static const Color appleBlue = Color(0xFF007AFF);

  /// 背景色 - 浅灰蓝
  static const Color background = Color(0xFFF5F7FA);

  /// 次级页面背景色
  static const Color surfaceSoft = Color(0xFFF8FAFC);

  /// 卡片背景色
  static const Color cardBackground = Colors.white;

  /// 浅色内容区背景
  static const Color sectionBackground = Color(0xFFF8FBFF);

  /// 浅蓝背景色（选中状态）
  static const Color lightBlueBackground = Color(0xFFF0F7FF);

  /// 品牌色浅底
  static const Color primarySoft = Color(0xFFEFF6FF);

  /// 品牌色浅边框
  static const Color primarySoftBorder = Color(0xFFBFDBFE);

  /// 浅灰边框色
  static const Color borderGray = Color(0xFFE5E7EB);

  /// 更轻的边框色
  static const Color borderLight = Color(0xFFE8EEF5);

  /// 卡片容器灰色背景
  static const Color containerGray = Color(0xFFF3F4F6);

  // ==================== 文本颜色 ====================
  /// 主文本颜色
  static const Color textPrimary = Color(0xFF333333);

  /// 次要文本颜色
  static const Color textSecondary = Color(0xFF666666);

  /// 提示文本颜色
  static const Color textHint = Color(0xFF999999);

  /// 第三级文本颜色
  static const Color textTertiary = Color(0xFF94A3B8);

  // ==================== 课程表莫兰迪色系 ====================
  /// 课程表配色方案（柔和的莫兰迪/马卡龙色系）
  static const List<Color> courseColors = [
    Color(0xFFE1F5FE), // 清爽蓝
    Color(0xFFF3E5F5), // 淡雅紫
    Color(0xFFE8F5E9), // 柔和绿
    Color(0xFFFFF3E0), // 温暖橙
    Color(0xFFFFEBEE), // 浪漫红
    Color(0xFFE0F7FA), // 宁静青
    Color(0xFFFFF8E1), // 明亮黄
    Color(0xFFFCE4EC), // 樱花粉
    Color(0xFFE0F2F1), // 薄荷绿
    Color(0xFFF9FBE7), // 柠檬黄
  ];

  // ==================== 功能色 ====================
  /// 成功色
  static const Color success = Colors.green;

  /// 警告色
  static const Color warning = Colors.orange;

  /// 警告浅色背景
  static const Color warningSoft = Color(0xFFFFF7ED);

  /// 错误色
  static const Color error = Colors.red;

  /// 错误浅色背景
  static const Color errorSoft = Color(0xFFFEF2F2);

  /// 信息色
  static const Color info = Colors.blue;

  /// 成功浅色背景
  static const Color successSoft = Color(0xFFF0FDF4);

  /// 中性浅色背景
  static const Color neutralSoft = Color(0xFFF8FAFC);

  /// 内容分割线颜色
  static const Color articleDivider = Color(0xFFE9EEF5);

  // ==================== 特殊颜色 ====================
  /// 分割线颜色
  static Color divider = Colors.grey[200]!;

  /// 阴影颜色
  static Color shadow = Colors.black.withValues(alpha: 0.05);

  /// 更轻的阴影颜色
  static Color shadowLight = Colors.black.withValues(alpha: 0.035);

  /// 更重的阴影颜色
  static Color shadowMedium = Colors.black.withValues(alpha: 0.07);
}
