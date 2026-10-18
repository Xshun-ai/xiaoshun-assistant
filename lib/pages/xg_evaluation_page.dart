import 'package:flutter/material.dart';

import '../features/xg/widgets/xg_evaluation_summary_card.dart';
import '../models/xg_evaluation_score.dart';
import '../models/xg_evaluation_semester.dart';
import '../services/campus_access_service.dart';
import '../services/log_service.dart';
import '../services/session_store.dart';
import '../services/xg_evaluation_service.dart';
import '../ui/components/app_page_app_bar.dart';

/// 综合评测页。
///
/// 展示学期综测总分和班级/专业排名。
class XgEvaluationPage extends StatefulWidget {
  const XgEvaluationPage({super.key});

  @override
  State<XgEvaluationPage> createState() => _XgEvaluationPageState();
}

class _XgEvaluationPageState extends State<XgEvaluationPage>
    with SingleTickerProviderStateMixin {
  static const String _campusUnavailableMessage = '校园网服务暂不可用，请稍后重试';

  final XgEvaluationService _service = XgEvaluationService();
  bool _loading = true;
  bool _loadingScore = false;
  List<XgEvaluationSemester> _semesters = [];
  XgEvaluationSemester? _selectedSemester;
  XgEvaluationScore? _score;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _init();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _init({bool preserveSelectedSemester = false}) async {
    final previousSelectedSemester = preserveSelectedSemester
        ? _selectedSemester
        : null;
    setState(() {
      _loading = true;
      _error = null;
      _semesters = [];
      _selectedSemester = null;
      _score = null;
      _loadingScore = false;
    });

    try {
      final token = await SessionStore().getAccessToken();
      if (token == null) {
        setState(() {
          _error = '未登录，请重新登录';
          _loading = false;
        });
        return;
      }

      final list = _deduplicateSemesters(await _service.getSemesters());
      if (!mounted) return;

      final nextSelectedSemester =
          _findMatchingSemester(list, previousSelectedSemester) ??
          (list.isNotEmpty ? list.first : null);
      setState(() {
        _semesters = list;
        _selectedSemester = nextSelectedSemester;
        _loading = false;
      });

      if (nextSelectedSemester != null) {
        await _fetchScore();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            CampusAccessService.isCampusNetworkUnavailableError(e) ||
                e is CampusServiceUnavailableException
            ? _campusUnavailableMessage
            : '获取失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _fetchScore() async {
    final semester = _selectedSemester;
    if (semester == null) return;

    setState(() {
      _loadingScore = true;
      _score = null;
      _error = null;
    });
    _animationController.reset();

    try {
      final score = await _service.getScore(semester);
      if (!mounted) return;

      setState(() {
        _score = score;
        _loadingScore = false;
      });
      if (score != null) {
        _animationController.forward();
      }
      await _service.saveOverviewCache(
        semesters: _semesters,
        selectedSemester: semester,
        score: score,
      );
    } catch (e) {
      await LogService().log('综测', '获取综测成绩异常: $e');
      if (!mounted) return;
      setState(() {
        _error =
            CampusAccessService.isCampusNetworkUnavailableError(e) ||
                e is CampusServiceUnavailableException
            ? _campusUnavailableMessage
            : '获取失败，请稍后重试';
        _score = null;
        _loadingScore = false;
      });
    }
  }

  XgEvaluationSemester? _findMatchingSemester(
    List<XgEvaluationSemester> semesters,
    XgEvaluationSemester? target,
  ) {
    if (target == null) return null;
    for (final semester in semesters) {
      if (semester.cpxn == target.cpxn &&
          semester.cpxq == target.cpxq &&
          semester.pcdm == target.pcdm) {
        return semester;
      }
    }
    return null;
  }

  List<XgEvaluationSemester> _deduplicateSemesters(
    List<XgEvaluationSemester> semesters,
  ) {
    final seen = <String>{};
    final result = <XgEvaluationSemester>[];
    for (final semester in semesters) {
      final key = '${semester.cpxn}|${semester.cpxq}|${semester.pcdm ?? ''}';
      if (seen.add(key)) {
        result.add(semester);
      }
    }
    return result;
  }

  Future<void> _refreshCurrentPage() async {
    if (_loading) return;
    await LogService().log('综测', '用户点击右上角刷新');
    await _init(preserveSelectedSemester: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppPageAppBar(
        title: '综合测评',
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refreshCurrentPage,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _semesters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 72,
                color: Colors.orange[300],
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _init, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    if (_semesters.isEmpty) {
      return const Center(child: Text('暂无综测数据'));
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSemesterSelector(),
          const SizedBox(height: 16),
          if (_loadingScore)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_score != null)
            FadeTransition(
              opacity: _fadeAnimation,
              child: XgEvaluationSummaryCard(score: _score!),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('未查询到该学期综测成绩'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSemesterSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF6A11CB),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<XgEvaluationSemester>(
                value: _selectedSemester,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF757575),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                hint: const Text('请选择学期'),
                items: _semesters.map((semester) {
                  return DropdownMenuItem(
                    value: semester,
                    child: Text(semester.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && value != _selectedSemester) {
                    setState(() {
                      _selectedSemester = value;
                      _score = null;
                    });
                    _fetchScore();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
