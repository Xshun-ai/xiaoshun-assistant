import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../ui/components/app_stat_item.dart';
import '../../../ui/components/status_chip.dart';
import '../../../services/teaching_plan_service.dart';
import 'grade_summary_card.dart';

class TeachingPlanContent extends StatefulWidget {
  final TeachingPlanData planData;

  const TeachingPlanContent({super.key, required this.planData});

  @override
  State<TeachingPlanContent> createState() => _TeachingPlanContentState();
}

class _TeachingPlanContentState extends State<TeachingPlanContent> {
  String _selectedSemester = '全部学期';

  List<String> get _semesters {
    final values = widget.planData.courses
        .map((item) => item.semester)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return <String>['全部学期', ...values];
  }

  List<TeachingPlanCourse> get _filteredCourses {
    return widget.planData.courses.where((course) {
      final matchesSemester =
          _selectedSemester == '全部学期' || course.semester == _selectedSemester;
      return matchesSemester;
    }).toList();
  }

  double get _filteredTotalCredits =>
      _filteredCourses.fold(0.0, (sum, item) => sum + item.credit);

  int get _filteredMajorCourseCount => _filteredCourses
      .where((course) => course.courseNature.contains('专业'))
      .length;

  int get _filteredExamCourseCount =>
      _filteredCourses.where((course) => course.isExam == '是').length;

  double get _requiredRatio {
    final courses = _filteredCourses;
    if (courses.isEmpty) {
      return 0;
    }
    final requiredCount = courses
        .where((course) => course.courseAttribute.contains('必修'))
        .length;
    return requiredCount / courses.length;
  }

  @override
  Widget build(BuildContext context) {
    final courses = _filteredCourses;

    if (widget.planData.courses.isEmpty) {
      return const _PlanEmptyView(
        icon: Icons.menu_book_outlined,
        title: '暂无教学计划数据',
        subtitle: '连接校园网后可同步教务系统中的教学执行计划',
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _TopStatsCard(
              selectedSemester: _selectedSemester,
              totalCredits: _filteredTotalCredits,
              majorCourseCount: _filteredMajorCourseCount,
              examCourses: _filteredExamCourseCount,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _SemesterSection(
              semesters: _semesters,
              selectedSemester: _selectedSemester,
              onSelected: (value) {
                setState(() {
                  _selectedSemester = value;
                });
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _RequiredRatioCard(requiredRatio: _requiredRatio),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: _ListHeader(
              count: courses.length,
              onReset: () {
                setState(() {
                  _selectedSemester = '全部学期';
                });
              },
            ),
          ),
        ),
        if (courses.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _PlanEmptyView(
              icon: Icons.search_off_rounded,
              title: '没有找到符合条件的课程',
              subtitle: '试试切换学期查看不同课程编排',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: SliverList.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RepaintBoundary(
                    child: _CoursePlanCard(
                      course: course,
                      onTap: () => _showCourseDetail(course),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _showCourseDetail(TeachingPlanCourse course) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990F172A),
      builder: (context) => _CourseDetailSheet(course: course),
    );
  }
}

class AcademicStatisticsContent extends StatelessWidget {
  final TeachingPlanData planData;

  const AcademicStatisticsContent({super.key, required this.planData});

  @override
  Widget build(BuildContext context) {
    if (planData.courses.isEmpty) {
      return const _PlanEmptyView(
        icon: Icons.analytics_outlined,
        title: '暂无学业统计数据',
        subtitle: '待教学计划同步成功后可查看统计结果',
      );
    }

    final semesterCredits = <String, double>{};
    final natureCounts = <String, int>{};
    int examCount = 0;
    int assessCount = 0;

    for (final course in planData.courses) {
      semesterCredits.update(
        course.semester,
        (value) => value + course.credit,
        ifAbsent: () => course.credit,
      );

      final nature = course.courseNature.isEmpty ? '未标注' : course.courseNature;
      natureCounts.update(nature, (value) => value + 1, ifAbsent: () => 1);

      if (course.assessmentType.contains('考试')) {
        examCount++;
      } else {
        assessCount++;
      }
    }

    final sortedSemesters = semesterCredits.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    final maxCredits = semesterCredits.values.fold<double>(
      0,
      (prev, value) => value > prev ? value : prev,
    );
    final totalCourses = planData.courses.length;
    final examRatio = totalCourses == 0 ? 0.0 : examCount / totalCourses;
    final assessRatio = totalCourses == 0 ? 0.0 : assessCount / totalCourses;

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsCard(
              title: '每学期学分负荷',
              child: Column(
                children: sortedSemesters.map((semester) {
                  final credits = semesterCredits[semester] ?? 0.0;
                  final progress = maxCredits == 0 ? 0.0 : credits / maxCredits;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                semester,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              '${credits.toStringAsFixed(1)} 学分',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE2E8F0),
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            _StatsCard(
              title: '课程性质比例',
              child: Column(
                children: natureCounts.entries.map((entry) {
                  final progress = totalCourses == 0 ? 0.0 : entry.value / totalCourses;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value} 门',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            _StatsCard(
              title: '考核与考试性质',
              child: Row(
                children: [
                  Expanded(
                    child: _ModeStatCard(
                      title: '考试模式占比',
                      value: '${(examRatio * 100).toStringAsFixed(0)}%',
                      background: const Color(0xFFEFF4FF),
                      foreground: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeStatCard(
                      title: '考查模式占比',
                      value: '${(assessRatio * 100).toStringAsFixed(0)}%',
                      background: const Color(0xFFE8F7FB),
                      foreground: const Color(0xFF0EA5E9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopStatsCard extends StatelessWidget {
  final String selectedSemester;
  final double totalCredits;
  final int majorCourseCount;
  final int examCourses;

  const _TopStatsCard({
    required this.selectedSemester,
    required this.totalCredits,
    required this.majorCourseCount,
    required this.examCourses,
  });

  @override
  Widget build(BuildContext context) {
    return GradeSummaryCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.cardBackground,
      border: Border.all(color: AppColors.borderLight),
      dividerColor: AppColors.articleDivider,
      header: Row(
        children: [
          const Expanded(
            child: Text(
              '教学计划',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          StatusChip(
            label: selectedSemester,
            backgroundColor: AppColors.primarySoft,
            foregroundColor: const Color(0xFF2563EB),
            borderColor: AppColors.primarySoftBorder,
          ),
        ],
      ),
      statItems: [
        AppStatItem(
          label: '学期学分',
          value: totalCredits.toStringAsFixed(1),
          valueStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        AppStatItem(
          label: '专业课数量',
          value: majorCourseCount.toString(),
          valueStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        AppStatItem(
          label: '考试课程',
          value: examCourses.toString(),
          valueStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SemesterSection extends StatelessWidget {
  final List<String> semesters;
  final String selectedSemester;
  final ValueChanged<String> onSelected;

  const _SemesterSection({
    required this.semesters,
    required this.selectedSemester,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(width: 6),
            const Text(
              '按学期查看',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedSemester,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: semesters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final semester = semesters[index];
              final selected = semester == selectedSemester;
              return GestureDetector(
                onTap: () => onSelected(semester),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      if (selected)
                        const BoxShadow(
                          color: Color(0x332563EB),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    semester,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RequiredRatioCard extends StatelessWidget {
  final double requiredRatio;

  const _RequiredRatioCard({required this.requiredRatio});

  @override
  Widget build(BuildContext context) {
    final ratioText = '${(requiredRatio * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '必修课程占比',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                ratioText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: requiredRatio,
              minHeight: 8,
              backgroundColor: const Color(0xFFCBD5E1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _LegendDot(color: Color(0xFF2563EB), label: '必修'),
              Spacer(),
              _LegendDot(color: Color(0xFFCBD5E1), label: '选修'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final int count;
  final VoidCallback onReset;

  const _ListHeader({required this.count, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.list_alt_rounded,
          size: 18,
          color: Color(0xFF2563EB),
        ),
        const SizedBox(width: 6),
        const Text(
          '课程计划明细',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onReset,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textTertiary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.rotate_left_rounded, size: 16),
          label: const Text(
            '重置筛选',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _CoursePlanCard extends StatelessWidget {
  final TeachingPlanCourse course;
  final VoidCallback onTap;

  const _CoursePlanCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRequired = course.courseAttribute.contains('必修');
    final badgeColor = isRequired
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFECFDF5);
    final badgeTextColor = isRequired
        ? const Color(0xFFE11D48)
        : const Color(0xFF059669);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          course.courseNature,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          course.courseCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    course.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    course.department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _PlanInlineMeta(
                        icon: Icons.workspace_premium_rounded,
                        text: '${course.credit.toStringAsFixed(1)} 学分',
                      ),
                      _PlanInlineMeta(
                        icon: Icons.schedule_rounded,
                        text: '${course.totalHours} 学时',
                      ),
                      _PlanInlineMeta(
                        icon: Icons.draw_rounded,
                        text: course.assessmentType,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    course.semester,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseDetailSheet extends StatelessWidget {
  final TeachingPlanCourse course;

  const _CourseDetailSheet({required this.course});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          course.courseNature,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        course.courseName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '课程编号：${course.courseCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DetailMetricCard(
                    label: '学分',
                    value: '${course.credit.toStringAsFixed(1)} 学分',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailMetricCard(
                    label: '总学时',
                    value: '${course.totalHours} 学时',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DetailMetricCard(
                    label: '考核方式',
                    value: course.assessmentType,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailMetricCard(
                    label: '是否必考',
                    value: course.isExam,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailBlock(
              label: '开课单位',
              value: course.department,
            ),
            const SizedBox(height: 12),
            _DetailHint(semester: course.semester),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '我知道了',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _StatsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ModeStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color background;
  final Color foreground;

  const _ModeStatCard({
    required this.title,
    required this.value,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanInlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PlanInlineMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String value;

  const _DetailBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHint extends StatelessWidget {
  final String semester;

  const _DetailHint({required this.semester});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.school_rounded,
            color: Color(0xFF2563EB),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '建议开课学期',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$semester 学期',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _PlanEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlanEmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(icon, size: 34, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
