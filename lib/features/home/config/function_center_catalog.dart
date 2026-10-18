import 'package:flutter/material.dart';

class FunctionCenterSectionDefinition {
  final String id;
  final String title;
  final Color accentColor;
  final int sort;

  const FunctionCenterSectionDefinition({
    required this.id,
    required this.title,
    required this.accentColor,
    required this.sort,
  });
}

class FunctionCenterEntryDefinition {
  final String id;
  final String sectionId;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int sort;

  const FunctionCenterEntryDefinition({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.sort,
  });
}

class FunctionCenterSectionIds {
  const FunctionCenterSectionIds._();

  static const study = 'study';
  static const schoolInfo = 'school_info';
  static const life = 'life';
  static const social = 'social';
}

class FunctionCenterEntryIds {
  const FunctionCenterEntryIds._();

  static const campusMap = 'campus_map_entry';
  static const announcement = 'announcement_entry';
  static const courseTable = 'course_table_entry';
  static const gradeQuery = 'grade_query_entry';
  static const evaluationQuery = 'evaluation_query_entry';
}

class FunctionCenterCatalog {
  const FunctionCenterCatalog._();

  static const sections = <FunctionCenterSectionDefinition>[
    FunctionCenterSectionDefinition(
      id: FunctionCenterSectionIds.study,
      title: '教务教学',
      accentColor: Color(0xFF4F46E5),
      sort: 10,
    ),
    FunctionCenterSectionDefinition(
      id: FunctionCenterSectionIds.schoolInfo,
      title: '学校通知',
      accentColor: Color(0xFF1E90FF),
      sort: 20,
    ),
    FunctionCenterSectionDefinition(
      id: FunctionCenterSectionIds.life,
      title: '智慧学工',
      accentColor: Color(0xFFF97316),
      sort: 30,
    ),
    FunctionCenterSectionDefinition(
      id: FunctionCenterSectionIds.social,
      title: '校园生活',
      accentColor: Color(0xFF06B6D4),
      sort: 40,
    ),
  ];

  static const entries = <FunctionCenterEntryDefinition>[
    FunctionCenterEntryDefinition(
      id: FunctionCenterEntryIds.courseTable,
      sectionId: FunctionCenterSectionIds.study,
      title: '课程表',
      subtitle: '本周与全部课程一览',
      icon: Icons.calendar_month_rounded,
      color: Color(0xFF3B82F6),
      sort: 10,
    ),
    FunctionCenterEntryDefinition(
      id: FunctionCenterEntryIds.gradeQuery,
      sectionId: FunctionCenterSectionIds.study,
      title: '学业中心',
      subtitle: '成绩、绩点、教学计划',
      icon: Icons.school_rounded,
      color: Color(0xFF6C63FF),
      sort: 20,
    ),
    FunctionCenterEntryDefinition(
      id: FunctionCenterEntryIds.announcement,
      sectionId: FunctionCenterSectionIds.schoolInfo,
      title: '校园通知',
      subtitle: '学校官方通知公告',
      icon: Icons.campaign_rounded,
      color: Color(0xFF6366F1),
      sort: 10,
    ),
    FunctionCenterEntryDefinition(
      id: FunctionCenterEntryIds.evaluationQuery,
      sectionId: FunctionCenterSectionIds.life,
      title: '综合评测',
      subtitle: '综测总分与班级/专业排名',
      icon: Icons.assessment_rounded,
      color: Color(0xFF10B981),
      sort: 10,
    ),
    FunctionCenterEntryDefinition(
      id: FunctionCenterEntryIds.campusMap,
      sectionId: FunctionCenterSectionIds.social,
      title: '校园地图',
      subtitle: '校园导航与位置查询',
      icon: Icons.map_outlined,
      color: Color(0xFF22C55E),
      sort: 20,
    ),
  ];

  static FunctionCenterSectionDefinition? sectionOf(String id) {
    for (final section in sections) {
      if (section.id == id) {
        return section;
      }
    }
    return null;
  }

  static FunctionCenterEntryDefinition? entryOf(String id) {
    for (final entry in entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  static List<FunctionCenterSectionDefinition> sortedSections() {
    final items = List<FunctionCenterSectionDefinition>.of(sections);
    items.sort((a, b) => a.sort.compareTo(b.sort));
    return items;
  }

  static List<FunctionCenterEntryDefinition> entriesOfSection(
    String sectionId,
  ) {
    final sectionEntries = entries
        .where((entry) => entry.sectionId == sectionId)
        .toList();
    sectionEntries.sort((a, b) => a.sort.compareTo(b.sort));
    return sectionEntries;
  }

  static String entryTitleOf(FunctionCenterEntryDefinition entry) =>
      entry.title;

  static IconData entryIconOf(FunctionCenterEntryDefinition entry) =>
      entry.icon;

  static Color entryColorOf(FunctionCenterEntryDefinition entry) => entry.color;
}
