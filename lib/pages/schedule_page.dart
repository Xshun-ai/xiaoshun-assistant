import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/campus_access_service.dart';
import '../services/schedule_service.dart';
import '../services/session_store.dart';
import '../services/sso_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../features/schedule/widgets/schedule_week_picker.dart';
import '../features/schedule/widgets/schedule_course_detail_sheet.dart';
import '../features/schedule/widgets/schedule_course_cell.dart';
import '../features/schedule/widgets/schedule_sync_header.dart';
import '../ui/components/app_page_app_bar.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final ScheduleService _scheduleService = ScheduleService();
  final SessionStore _sessionStore = SessionStore();
  final SsoService _ssoService = SsoService();

  List<Map<String, dynamic>> _weekCourses = [];
  List<Map<String, String>> _weekDates = [];
  List<Map<String, String>> _bigPeriods = [];
  List<ScheduleTerm> _terms = [];
  bool _loading = true;
  int _currentWeek = 1; // 实际当前周
  int _selectedWeek = 1; // 用户选择的周，0 表示全部
  final int _maxWeek = 25; // 最大周次
  bool _isPreSemester = false; // 是否处于开学前模式
  String? _errorMessage;
  String? _selectedTermId;
  String? _periodModeId;

  // 缓存的原始数据，用于切换周次时不重新网络请求
  Map<String, dynamic>? _cachedData;
  String? _cachedTermName;

  // 解析结果缓存，避免重复解析
  Map<int, List<Map<String, dynamic>>>? _parsedCoursesCache;
  int? _cachedDataHash;

  // 布局常量
  final double _leftColumnWidth = AppSizes.scheduleLeftColumnWidth;
  final double _headerHeight = AppSizes.scheduleHeaderHeight;

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
  }

  Future<void> _initializeSchedule() async {
    String? preferredTermId;
    try {
      preferredTermId = await _sessionStore.getScheduleSelectedTermId();
      await _loadCachedScheduleData(termId: preferredTermId);
      await _restoreCachedTermOptions(preferredTermId);

      final token = await _ensureValidMobileToken();
      final results = await Future.wait<Object>([
        _scheduleService.fetchTerms(token),
        _scheduleService.fetchPeriodModeId(token),
      ]);
      final terms = results[0] as List<ScheduleTerm>;
      final periodModeId = results[1] as String;
      final latestPreferredTermId =
          await _sessionStore.getScheduleSelectedTermId() ?? preferredTermId;
      final selectedTerm =
          terms.where((term) => term.id == latestPreferredTermId).firstOrNull ??
          terms.where((term) => term.isCurrent).firstOrNull ??
          (terms.isNotEmpty ? terms.first : null);

      if (selectedTerm == null) {
        throw Exception('未获取到可用课表学期');
      }
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _periodModeId = periodModeId;
        _selectedTermId = selectedTerm.id;
      });
      await _sessionStore.saveScheduleSelectedTermId(selectedTerm.id);
      await _loadScheduleData();
    } catch (e) {
      debugPrint('初始化课程表学期出错: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = _cachedData == null
              ? CampusAccessService.toUserFacingErrorMessage(
                  e,
                  fallback: '获取课表学期失败，请稍后重试',
                  networkMessage: '网络连接异常，请稍后重试',
                  campusNetworkMessage: '校园网服务暂不可用，请稍后重试',
                )
              : null;
        });
      }
    }
  }

  Future<void> _restoreCachedTermOptions(String? preferredTermId) async {
    final cachedTerms = await _sessionStore.getCachedScheduleTerms();
    if (cachedTerms.isEmpty || !mounted) {
      return;
    }

    final terms = cachedTerms
        .map(
          (item) => ScheduleTerm(
            id: item['id']!,
            name: item['name']!,
            isCurrent: item['id'] == preferredTermId,
          ),
        )
        .toList();
    final selectedTermId = terms.any((term) => term.id == preferredTermId)
        ? terms.firstWhere((term) => term.id == preferredTermId).id
        : terms.first.id;

    setState(() {
      _terms = terms;
      _selectedTermId = selectedTermId;
    });

    if (_cachedData == null ||
        _cachedData?['_cache_term_id']?.toString() != selectedTermId) {
      await _loadCachedScheduleData(termId: selectedTermId);
    }
  }

  Future<void> _loadCachedScheduleData({String? termId}) async {
    final cachedJson = await _sessionStore.getScheduleData(termId: termId);
    if (cachedJson == null || cachedJson.isEmpty) {
      return;
    }

    try {
      final data = jsonDecode(cachedJson);
      if (data is! Map) {
        return;
      }
      _cachedData = Map<String, dynamic>.from(data);
      final cachedTermId = data['_cache_term_id']?.toString();
      if (cachedTermId != null &&
          cachedTermId.isNotEmpty &&
          termId != null &&
          cachedTermId != termId) {
        debugPrint('忽略学期不匹配的课表缓存: cache=$cachedTermId selected=$termId');
        _cachedData = null;
        return;
      }
      final cachedTermName = data['_cache_term_name']?.toString().trim();
      _cachedTermName = cachedTermName == null || cachedTermName.isEmpty
          ? null
          : cachedTermName;
      if (termId != null && termId.isNotEmpty) {
        _selectedTermId = termId;
      }
      _processData(_cachedData!, updateSelectedWeek: true);
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('读取课程表缓存失败: $e');
    }
  }

  Future<String> _ensureValidMobileToken({bool forceRefresh = false}) async {
    final accessToken = await _sessionStore.getAccessToken();
    final username = await _sessionStore.getUsername();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('未登录，无法获取移动端Token');
    }
    if (username == null || username.isEmpty) {
      throw Exception('未获取到当前用户名，无法执行移动端SSO');
    }

    return _ssoService.ensureValidMobileToken(
      store: _sessionStore,
      accessToken: accessToken,
      username: username,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _loadScheduleData({int? week, bool forceRefresh = false}) async {
    // 如果指定了周次，更新选中状态
    if (week != null) {
      _selectedWeek = week;
    }

    final hadVisibleContent = _cachedData != null || _weekCourses.isNotEmpty;
    if (mounted) {
      setState(() {
        _loading = !hadVisibleContent;
      });
    }

    try {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }

      // 优先加载缓存（无论是否指定周次，都先尝试显示缓存）
      final termId = _selectedTermId;
      final cachedJson = forceRefresh
          ? null
          : await _sessionStore.getScheduleData(termId: termId);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(cachedJson);
        final cachedTermId = data['_cache_term_id']?.toString();
        if (cachedTermId != null &&
            cachedTermId.isNotEmpty &&
            termId != null &&
            cachedTermId != termId) {
          debugPrint('忽略学期不匹配的课表缓存: cache=$cachedTermId selected=$termId');
        } else {
          final cachedTermName = data['_cache_term_name']?.toString().trim();
          _cachedTermName = cachedTermName == null || cachedTermName.isEmpty
              ? null
              : cachedTermName;
          _cachedData = data;
          _processData(data, updateSelectedWeek: week == null);
          if (mounted) {
            setState(() {
              _loading = false;
            });
          }
        }
      }

      // 尝试后台刷新
      // 仅在未指定周次时请求网络
      if (week == null || forceRefresh) {
        try {
          final token = await _ensureValidMobileToken();
          final data = await _scheduleService.fetchFullSchedule(
            token,
            termId: termId,
            periodModeId: _periodModeId,
          );
          if (data != null && mounted) {
            await _sessionStore.saveScheduleData(
              jsonEncode(data),
              termId: termId!,
              termName: _selectedTermName,
            );
            data['_cache_term_id'] = termId;
            data['_cache_term_name'] = _selectedTermName;
            _cachedData = data;
            // 强制刷新时清空缓存，确保重新解析
            if (forceRefresh) {
              _parsedCoursesCache = null;
              _cachedDataHash = null;
            }
            _processData(data, updateSelectedWeek: !forceRefresh);
          }
        } catch (e) {
          if (SsoService.isCorruptedMobileTokenError(e)) {
            await _sessionStore.clearYdjwToken();
            final refreshedToken = await _ensureValidMobileToken(
              forceRefresh: true,
            );
            final data = await _scheduleService.fetchFullSchedule(
              refreshedToken,
              termId: termId,
              periodModeId: _periodModeId,
            );
            if (data != null && mounted) {
              await _sessionStore.saveScheduleData(
                jsonEncode(data),
                termId: termId!,
                termName: _selectedTermName,
              );
              data['_cache_term_id'] = termId;
              data['_cache_term_name'] = _selectedTermName;
              _cachedData = data;
              // 强制刷新时清空缓存，确保重新解析
              if (forceRefresh) {
                _parsedCoursesCache = null;
                _cachedDataHash = null;
              }
              _processData(data, updateSelectedWeek: !forceRefresh);
            }
          } else {
            rethrow;
          }
        }
      } else if (_cachedData != null) {
        // 切换周次时，直接用缓存数据重新解析
        _processData(_cachedData!, updateSelectedWeek: false);
      }
    } catch (e) {
      debugPrint('加载课程表出错: $e');
      if (mounted && _cachedData == null) {
        setState(() {
          _errorMessage = CampusAccessService.toUserFacingErrorMessage(
            e,
            fallback: '获取课表失败，请稍后重试',
            networkMessage: '网络连接异常，请稍后重试',
            campusNetworkMessage: '校园网服务暂不可用，请稍后重试',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _processData(
    Map<String, dynamic> data, {
    bool updateSelectedWeek = false,
  }) {
    final preSemester = _scheduleService.isPreSemester(data);
    final realCurrentWeek = _scheduleService.getCurrentWeek(data);

    if (updateSelectedWeek) {
      if (preSemester) {
        // 开学前模式，默认选中”全部”
        _selectedWeek = 0;
      } else {
        _selectedWeek = realCurrentWeek;
      }
    }

    // 计算数据哈希值，用于判断是否需要重新解析
    final dataHash = data.hashCode;
    final needReparse = _cachedDataHash != dataHash ||
                        _parsedCoursesCache == null ||
                        !(_parsedCoursesCache!.containsKey(_selectedWeek));

    List<Map<String, dynamic>> courses;

    if (needReparse) {
      // 需要重新解析
      debugPrint('DEBUG: [完整课表] 开始解析第 $_selectedWeek 周课程 (targetWeek: $_selectedWeek)');

      courses = _scheduleService.parseWeekCourses(
        data,
        targetWeek: _selectedWeek,
      );

      debugPrint('DEBUG: [完整课表] 第 $_selectedWeek 周共找到 ${courses.length} 门课程');

      // 缓存解析结果
      _parsedCoursesCache ??= {};
      _parsedCoursesCache![_selectedWeek] = courses;
      _cachedDataHash = dataHash;
    } else {
      // 使用缓存的解析结果
      courses = _parsedCoursesCache![_selectedWeek]!;
      debugPrint('DEBUG: [完整课表] 使用缓存的第 $_selectedWeek 周课程数据 (${courses.length} 门)');
    }

    final dates = _selectedWeek == 0
        ? <Map<String, String>>[] // 全部模式不显示日期
        : _scheduleService.getWeekDates(data, targetWeek: _selectedWeek);
    final periods = _scheduleService.getBigPeriods(data);

    if (mounted) {
      setState(() {
        _isPreSemester = preSemester;
        _weekCourses = courses;
        if (updateSelectedWeek) {
          // 开学前模式下 _currentWeek 设为 0，避免与任何周次匹配而错误高亮”今天”
          _currentWeek = preSemester ? 0 : realCurrentWeek;
        }
        _weekDates = dates;
        _bigPeriods = periods;
      });
    }
  }

  void _changeWeek(int delta) {
    if (_selectedWeek == 0) {
      // 从"全部"模式切换到第1周
      _loadScheduleData(week: 1);
      return;
    }
    final newWeek = _selectedWeek + delta;
    if (newWeek >= 1 && newWeek <= _maxWeek) {
      _loadScheduleData(week: newWeek);
    }
  }

  void _showWeekPicker() {
    ScheduleWeekPicker.show(
      context,
      currentWeek: _currentWeek,
      selectedWeek: _selectedWeek,
      maxWeek: _maxWeek,
      terms: _terms,
      selectedTermId: _selectedTermId,
      onTermSelected: _selectTerm,
      showAllOption: true, // 始终显示"全部"选项
      onWeekSelected: (week) => _loadScheduleData(week: week),
    );
  }

  Future<void> _selectTerm(ScheduleTerm selectedTerm) async {
    setState(() {
      _selectedTermId = selectedTerm.id;
      _selectedWeek = 0;
      _cachedData = null;
      _cachedTermName = null;
      _weekCourses = [];
      _weekDates = [];
      _bigPeriods = [];
      // 清空解析缓存
      _parsedCoursesCache = null;
      _cachedDataHash = null;
    });
    await _sessionStore.saveScheduleSelectedTermId(selectedTerm.id);
    await _loadScheduleData();
  }

  Future<void> _refreshSchedule() async {
    await _loadScheduleData(forceRefresh: true);
  }

  void _showCourseDetails(Map<String, dynamic> course) {
    ScheduleCourseDetailSheet.show(context, course);
  }

  /// 获取 AppBar 标题文本
  String get _titleText {
    if (_selectedWeek == 0) return '全部课表';
    return '第 $_selectedWeek 周';
  }

  String get _selectedTermName {
    for (final term in _terms) {
      if (term.id == _selectedTermId) return term.name;
    }
    return _cachedTermName ?? _selectedTermId ?? '课程表';
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllMode = _selectedWeek == 0;
    final content = _loading && _weekCourses.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null && _weekCourses.isEmpty
        ? _buildErrorState()
        : _buildScheduleBody();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppPageAppBar(
        title: '',
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _selectedWeek > 1 || isAllMode
                        ? () {
                            if (isAllMode) {
                              _loadScheduleData(week: _maxWeek);
                            } else {
                              _changeWeek(-1);
                            }
                          }
                        : null,
                  ),
                  GestureDetector(
                    onTap: _showWeekPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedTermName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _titleText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _selectedWeek < _maxWeek
                        ? () {
                            if (isAllMode) {
                              _loadScheduleData(week: 1);
                            } else {
                              _changeWeek(1);
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新当前学期课表',
            onPressed: _refreshSchedule,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '暂无课表数据',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleBody() {
    // 确保大节数据存在
    if (_bigPeriods.isEmpty) {
      _bigPeriods = [
        {'name': '第一大节', 'sections': '01,02'},
        {'name': '第二大节', 'sections': '03,04'},
        {'name': '第三大节', 'sections': '05,06'},
        {'name': '第四大节', 'sections': '07,08'},
        {'name': '第五大节', 'sections': '09,10'},
      ];
    }

    if (_selectedWeek == 0) {
      return _buildAllScheduleBody();
    }

    final bool isAllMode = _selectedWeek == 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _leftColumnWidth;
        final columnWidth = math.max(
          availableWidth / 7,
          AppSizes.scheduleMinColumnWidth,
        );
        final totalGridWidth = columnWidth * 7;

        // 计算自适应行高
        final availableHeight = constraints.maxHeight - _headerHeight - 1;
        final int rowCount = _bigPeriods.isNotEmpty ? _bigPeriods.length : 5;
        final double cellHeight = math.max(
          availableHeight / rowCount,
          AppSizes.scheduleMinCellHeight,
        );

        // 获取当前显示的月份/标签
        String monthText;
        if (isAllMode) {
          monthText = '全部';
        } else {
          monthText = '${DateTime.now().month}月';
          if (_weekDates.isNotEmpty) {
            try {
              final firstDateMap = _weekDates.firstWhere(
                (e) => (e['date'] ?? '').isNotEmpty,
                orElse: () => _weekDates.first,
              );
              final dateStr = firstDateMap['date'];
              if (dateStr != null && dateStr.length >= 7) {
                final date = DateTime.parse(dateStr);
                monthText = '${date.month}月';
              }
            } catch (e) {
              // 忽略解析错误
            }
          }
        }

        return Column(
          children: [
            // 顶部表头区域
            Container(
              height: _headerHeight,
              color: Colors.white,
              child: Row(
                children: [
                  // 左上角月份/全部
                  SizedBox(
                    width: _leftColumnWidth,
                    child: Center(
                      child: Text(
                        monthText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  // 右侧星期表头（同步滚动）
                  Expanded(
                    child: ScheduleSyncHeader(
                      columnWidth: columnWidth,
                      weekDates: _weekDates,
                      scrollController: _horizontalController,
                      isCurrentWeek:
                          !_isPreSemester &&
                          !isAllMode &&
                          _selectedWeek == _currentWeek,
                      hideDates: isAllMode, // 全部模式隐藏日期
                    ),
                  ),
                ],
              ),
            ),

            // 阴影分隔
            Container(height: 1, color: Colors.grey[200]),

            // 主体区域
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧时间栏
                    SizedBox(
                      width: _leftColumnWidth,
                      child: Column(
                        children: List.generate(_bigPeriods.length, (index) {
                          return Container(
                            height: cellHeight,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[100]!,
                                  width: 1,
                                ),
                                right: BorderSide(
                                  color: Colors.grey[100]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: _buildTimeCell(index),
                          );
                        }),
                      ),
                    ),

                    // 右侧课程网格（横向滚动）
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: totalGridWidth,
                          child: Row(
                            children: List.generate(7, (dayIndex) {
                              return SizedBox(
                                width: columnWidth,
                                child: _buildCourseDayColumn(
                                  dayIndex,
                                  cellHeight,
                                  columnWidth,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAllScheduleBody() {
    final dayNames = const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final groupedCourses = <int, List<Map<String, dynamic>>>{};
    for (final course in _weekCourses) {
      final day = course['weekDay'] as int?;
      if (day == null || day < 1 || day > 7) continue;
      groupedCourses.putIfAbsent(day, () => []).add(course);
    }

    final days = groupedCourses.keys.toList()..sort();
    if (days.isEmpty) {
      return const Center(child: Text('暂无课表数据'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      // 优化性能: 减少预缓存范围
      // 兼容旧版 Flutter 保留 cacheExtent；新版已改名为 scrollCacheExtent。
      // ignore: deprecated_member_use
      cacheExtent: 200,
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final courses = groupedCourses[day]!
          ..sort((a, b) {
            final periodCompare = (a['bigPeriodIndex'] as int).compareTo(
              b['bigPeriodIndex'] as int,
            );
            if (periodCompare != 0) return periodCompare;
            final timeCompare = (a['startTime'] as String).compareTo(
              b['startTime'] as String,
            );
            if (timeCompare != 0) return timeCompare;
            return (a['course'] as String).compareTo(b['course'] as String);
          });

        return Padding(
          padding: EdgeInsets.only(bottom: index == days.length - 1 ? 0 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  dayNames[day - 1],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...courses.map(
                (course) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RepaintBoundary(
                    child: _AllScheduleCourseTile(
                      course: course,
                      periodName: _periodRange(course),
                      onTap: () => _showCourseDetails(course),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _periodName(int index) {
    if (index >= 0 && index < _bigPeriods.length) {
      return _bigPeriods[index]['name'] ?? '${index + 1}大节';
    }
    return '未知大节';
  }

  String _periodRange(Map<String, dynamic> course) {
    final start = course['bigPeriodIndex'] as int? ?? -1;
    final span = course['bigPeriodSpan'] as int? ?? 1;
    final end = start + span - 1;
    if (start < 0 || end >= _bigPeriods.length || span <= 1) {
      return _periodName(start);
    }
    return '${_periodName(start)}至${_periodName(end)}';
  }

  final ScrollController _horizontalController = ScrollController();

  Widget _buildTimeCell(int index) {
    final periodNum = index + 1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$periodNum',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        Text('大节', style: TextStyle(fontSize: 8.5, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildCourseDayColumn(
    int dayIndex,
    double cellHeight,
    double columnWidth,
  ) {
    final dayCourses = _weekCourses
        .where((course) => course['weekDay'] == dayIndex + 1)
        .toList();
    final uniqueCourses = <String, Map<String, dynamic>>{};
    for (final course in dayCourses) {
      final key =
          '${course['course']}|${course['startTime']}|${course['endTime']}|${course['teacher']}|${course['bigPeriodIndex']}';
      uniqueCourses.putIfAbsent(key, () => course);
    }

    final courses = uniqueCourses.values.toList()
      ..sort((a, b) {
        final startCompare = (a['bigPeriodIndex'] as int).compareTo(
          b['bigPeriodIndex'] as int,
        );
        if (startCompare != 0) return startCompare;
        return (b['bigPeriodSpan'] as int).compareTo(a['bigPeriodSpan'] as int);
      });
    final laneEnds = <int>[];
    final lanes = <Map<String, dynamic>, int>{};
    for (final course in courses) {
      final start = course['bigPeriodIndex'] as int;
      final span = course['bigPeriodSpan'] as int? ?? 1;
      final lane = laneEnds.indexWhere((end) => end <= start);
      if (lane == -1) {
        lanes[course] = laneEnds.length;
        laneEnds.add(start + span);
      } else {
        lanes[course] = lane;
        laneEnds[lane] = start + span;
      }
    }

    final totalHeight = cellHeight * _bigPeriods.length;
    final laneCount = laneEnds.isEmpty ? 1 : laneEnds.length;
    final laneWidth = columnWidth / laneCount;

    // 使用 RepaintBoundary 包裹整列，减少重绘范围
    return RepaintBoundary(
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            Column(
              children: List.generate(
                _bigPeriods.length,
                (index) => SizedBox(
                  height: cellHeight,
                  child: ScheduleCourseCell(course: const {}, onTap: () {}),
                ),
              ),
            ),
            ...courses.map((course) {
              final start = course['bigPeriodIndex'] as int? ?? -1;
              final span = course['bigPeriodSpan'] as int? ?? 1;
              if (start < 0 || start >= _bigPeriods.length) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: start * cellHeight,
                left: lanes[course]! * laneWidth,
                width: laneWidth,
                height: math.min(
                  totalHeight - start * cellHeight,
                  cellHeight * span,
                ),
                child: ScheduleCourseCell(
                  course: course,
                  onTap: () => _showCourseDetails(course),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AllScheduleCourseTile extends StatelessWidget {
  final Map<String, dynamic> course;
  final String periodName;
  final VoidCallback onTap;

  const _AllScheduleCourseTile({
    required this.course,
    required this.periodName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final courseName = course['course']?.toString() ?? '未知课程';
    final courseCode = course['courseCode']?.toString() ?? '';
    final weeks = course['weeks']?.toString() ?? '';
    final startTime = course['startTime']?.toString() ?? '';
    final endTime = course['endTime']?.toString() ?? '';
    final location = course['location']?.toString() ?? '';
    final teacher = course['teacher']?.toString() ?? '';
    final color =
        AppColors.courseColors[courseName.hashCode.abs() %
            AppColors.courseColors.length];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 54,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (courseCode.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        courseCode,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _AllScheduleMeta(
                          icon: Icons.schedule_rounded,
                          text: '$periodName · $startTime-$endTime',
                        ),
                        if (weeks.isNotEmpty)
                          _AllScheduleMeta(
                            icon: Icons.date_range_rounded,
                            text: '第 $weeks 周',
                          ),
                        if (location.isNotEmpty)
                          _AllScheduleMeta(
                            icon: Icons.location_on_outlined,
                            text: location,
                          ),
                        if (teacher.isNotEmpty)
                          _AllScheduleMeta(
                            icon: Icons.person_outline_rounded,
                            text: teacher,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllScheduleMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AllScheduleMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
      ],
    );
  }
}
