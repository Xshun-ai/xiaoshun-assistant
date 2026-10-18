import 'package:flutter/material.dart';
import '../features/grade/widgets/grade_analysis_content.dart';
import '../features/grade/widgets/grade_course_cards.dart';
import '../features/grade/widgets/grade_filter_bar.dart';
import '../features/grade/widgets/grade_overview_header_card.dart';
import '../features/grade/widgets/teaching_plan_content.dart';
import '../services/campus_access_service.dart';
import '../services/grade_service.dart';
import '../services/log_service.dart';
import '../services/teaching_plan_service.dart';
import '../ui/components/app_page_app_bar.dart';

class GradePage extends StatefulWidget {
  const GradePage({super.key});

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage>
    with SingleTickerProviderStateMixin {
  final _gradeService = GradeService();
  final _teachingPlanService = TeachingPlanService();
  late final PageController _pageController;

  // 数据状态
  Map<String, List<Grade>> _allGrades = {};
  TeachingPlanData _teachingPlanData = TeachingPlanData.empty();
  List<String> _semesters = [];
  String? _selectedTermId;
  bool _isLoading = true;
  String? _error;

  // 页面状态
  int _currentIndex = 0; // 0: 列表, 1: 分析, 2: 教学计划, 3: 学业统计

  // 筛选状态
  List<String> _availableAttributes = ['全部'];
  String _filterAttribute = '全部';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _initData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    // 1. 优先加载缓存，实现"秒开"体验
    bool hasCache = false;
    try {
      final cacheData = await _gradeService.loadFromCache();
      final teachingPlanCache = await _teachingPlanService.loadFromCache();
      if ((cacheData.isNotEmpty || teachingPlanCache.courses.isNotEmpty) &&
          mounted) {
        _updateUI(cacheData, teachingPlanData: teachingPlanCache);
        hasCache = true;
      }
    } catch (e) {
      debugPrint('Load cache failed: $e');
    }

    // 如果没有缓存，显示加载圈
    if (!hasCache && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    // 2. 后台静默刷新数据
    try {
      final gradeFuture = _gradeService.fetchAllGrades();
      final teachingPlanFuture = _teachingPlanService.fetchAllCourses();
      final data = await gradeFuture;
      final teachingPlanData = await teachingPlanFuture;
      await LogService().log('查看学业中心', '用户进入学业中心页面');

      if (mounted) {
        _updateUI(data, teachingPlanData: teachingPlanData);
      }
    } catch (e) {
      if (mounted) {
        // 如果已有缓存显示，则仅打印日志，不显示全屏错误
        if (hasCache) {
          debugPrint('Silent refresh error: $e');
        } else {
          setState(() {
            _error = CampusAccessService.isCampusNetworkUnavailableError(e)
                ? '校园网服务暂不可用，请稍后重试'
                : '获取失败，请稍后重试';
            _isLoading = false;
          });
        }
      }
    }
  }

  void _updateUI(
    Map<String, List<Grade>> data, {
    TeachingPlanData? teachingPlanData,
  }) {
    if (!mounted) return;

    setState(() {
      _allGrades = data;
      _teachingPlanData = teachingPlanData ?? _teachingPlanData;

      // 处理学期列表
      _semesters = data.keys.toList()..sort((a, b) => b.compareTo(a)); // 降序排列
      if (!_semesters.contains('全部')) {
        _semesters.insert(0, '全部'); // 增加全部选项
      }

      // 提取所有课程属性
      final Set<String> attributes = {};
      for (var list in data.values) {
        for (var grade in list) {
          if (grade.attribute.isNotEmpty) {
            attributes.add(grade.attribute);
          }
        }
      }
      _availableAttributes = ['全部', ...attributes.toList()..sort()];

      // 默认选中最新学期（仅在未选择时设置）
      if (_selectedTermId == null) {
        if (_semesters.length > 1) {
          _selectedTermId = _semesters[1];
        } else if (_semesters.isNotEmpty) {
          _selectedTermId = _semesters.first;
        }
      }

      _isLoading = false;
      _error = null;
    });
  }

  List<Grade> get _currentGrades {
    if (_selectedTermId == null) return [];

    List<Grade> grades;
    if (_selectedTermId == '全部') {
      grades = _allGrades.values.expand((x) => x).toList();
    } else {
      grades = _allGrades[_selectedTermId] ?? [];
    }

    if (_filterAttribute == '全部') return grades;
    return grades.where((g) => g.attribute == _filterAttribute).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppPageAppBar(
        title: '学业中心',
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _initData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
          ? _buildError()
          : PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (_currentIndex != index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  const labels = <String>['成绩列表', '成绩分析', '教学计划', '学业统计'];
                  LogService().log('滑动切换标签页', '用户滑动到: ${labels[index]}');
                }
              },
              children: [
                _buildGradeListTab(theme),
                _buildAnalysisTab(theme),
                TeachingPlanContent(planData: _teachingPlanData),
                AcademicStatisticsContent(planData: _teachingPlanData),
              ],
            ),
      bottomNavigationBar: _AcademicBottomBar(
        currentIndex: _currentIndex,
        onSelected: (index) {
          if (_currentIndex != index) {
            setState(() {
              _currentIndex = index;
            });
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
            );
          }
          const labels = <String>['成绩列表', '成绩分析', '教学计划', '学业统计'];
          LogService().log('切换标签页', '用户切换到: ${labels[index]}');
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Theme.of(context).primaryColor),
          const SizedBox(height: 16),
          const Text('正在获取成绩数据...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error ?? '未知错误', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 24),
          FilledButton.tonal(onPressed: _initData, child: const Text('重试')),
        ],
      ),
    );
  }

  // --- Tab 1: 成绩列表 ---

  Widget _buildGradeListTab(ThemeData theme) {
    final currentGrades = _currentGrades;
    final gpa = _calculateGPA(currentGrades);
    final totalCredits = _calculateTotalCredits(currentGrades);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildHeaderCard(theme, gpa, totalCredits),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: _buildFilterBar(theme),
            minHeight: 60,
            maxHeight: 60,
          ),
        ),
        if (currentGrades.isEmpty)
          const SliverFillRemaining(child: Center(child: Text('本学期暂无成绩')))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildGradeCard(theme, currentGrades[index], index),
                childCount: currentGrades.length,
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }

  Widget _buildHeaderCard(ThemeData theme, double gpa, double credits) {
    return GradeOverviewHeaderCard(
      gpa: gpa,
      credits: credits,
      courseCount: _currentGrades.length,
      creditsLabel: '已修学分',
      termLabel: _selectedTermId ?? '全部',
      variant: GradeOverviewHeaderVariant.neutral,
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return GradeFilterBar(
      theme: theme,
      semesters: _semesters,
      selectedTermId: _selectedTermId,
      onTermChanged: (value) {
        setState(() => _selectedTermId = value);
        LogService().log('筛选学期', '用户选择学期: $value');
      },
      attributes: _availableAttributes,
      selectedAttribute: _filterAttribute,
      onAttributeChanged: (value) {
        setState(() => _filterAttribute = value);
        LogService().log('筛选属性', '用户筛选课程属性: $value');
      },
    );
  }

  Widget _buildGradeCard(ThemeData theme, Grade grade, int index) {
    return GradeExpandableCourseCard(theme: theme, grade: grade);
  }

  // --- Tab 2: 成绩分析 ---

  Widget _buildAnalysisTab(ThemeData theme) {
    return GradeAnalysisContent(
      allGrades: _allGrades,
      semesters: _semesters,
      selectedTermId: _selectedTermId,
    );
  }

  double _calculateGPA(List<Grade> grades) {
    if (grades.isEmpty) return 0.0;
    double totalPoints = 0.0;
    double totalCredits = 0.0;
    for (var g in grades) {
      // 只计算绩点不为0的课程
      if (g.gpa == 0) continue;

      totalPoints += g.gpa * g.credit;
      totalCredits += g.credit;
    }
    return totalCredits == 0 ? 0.0 : totalPoints / totalCredits;
  }

  double _calculateTotalCredits(List<Grade> grades) {
    return grades
        .where((g) => g.isPassed)
        .fold(0.0, (sum, g) => sum + g.credit);
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _StickyHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

class _AcademicBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const _AcademicBottomBar({
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = <({IconData icon, String label})>[
      (icon: Icons.format_list_bulleted_rounded, label: '成绩列表'),
      (icon: Icons.analytics_rounded, label: '成绩分析'),
      (icon: Icons.home_rounded, label: '教学计划'),
      (icon: Icons.bar_chart_rounded, label: '学业统计'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = currentIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedScale(
                  scale: selected ? 1.04 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: selected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
