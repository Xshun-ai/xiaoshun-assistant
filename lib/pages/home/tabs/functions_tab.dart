import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/home/config/function_center_catalog.dart';
import '../../../features/home/widgets/feature_card.dart';
import '../../../services/log_service.dart';
import '../../portal_announcements_list_page.dart';
import '../../../features/campus_map/campus_map_page.dart';
import '../../grade_page.dart';
import '../../schedule_page.dart';
import '../../xg_evaluation_page.dart';

/// 功能Tab - 展示所有功能模块的服务大厅
class FunctionsTab extends StatefulWidget {
  final Future<void> Function()? onRefresh;

  const FunctionsTab({super.key, this.onRefresh});

  @override
  State<FunctionsTab> createState() => _FunctionsTabState();
}

class _FunctionsTabState extends State<FunctionsTab>
    with AutomaticKeepAliveClientMixin {
  static const double _sectionAnchorOffset = 92;

  final ScrollController _contentScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _contentViewportKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = {};

  List<_ServiceSectionData> _latestVisibleSections = const [];
  String? _openingFeatureKey;
  String _searchQuery = '';
  String _activeSectionId = FunctionCenterSectionIds.study;
  bool _pendingSectionSync = false;
  bool _isProgrammaticSectionScroll = false;
  int _programmaticSectionScrollToken = 0;

  @override
  void initState() {
    super.initState();
    _contentScrollController.addListener(_handleContentScroll);
  }

  @override
  void dispose() {
    _contentScrollController.removeListener(_handleContentScroll);
    _contentScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  _ServiceEntryAction _buildSimpleEntryAction({
    required String entryId,
    required String logDetails,
    required WidgetBuilder pageBuilder,
    Future<void> Function()? afterPop,
  }) {
    return _ServiceEntryAction(
      isLoading: _isOpening(entryId),
      onTap: () => _handleSimpleFeatureTap(
        featureKey: entryId,
        logDetails: logDetails,
        pageBuilder: pageBuilder,
        afterPop: afterPop,
      ),
    );
  }

  Future<void> _handlePullToRefresh() async {
    await widget.onRefresh?.call();
    _scheduleSectionSync();
  }

  bool _isOpening(String featureKey) => _openingFeatureKey == featureKey;

  Future<void> _runSingleNavigationTask(
    String featureKey,
    Future<void> Function() task,
  ) async {
    if (_openingFeatureKey != null) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) {
      setState(() {
        _openingFeatureKey = featureKey;
      });
    }
    try {
      await task();
    } finally {
      if (mounted) {
        setState(() {
          _openingFeatureKey = null;
        });
      } else {
        _openingFeatureKey = null;
      }
    }
  }

  Future<void> _handleSimpleFeatureTap({
    required String featureKey,
    required String logDetails,
    required WidgetBuilder pageBuilder,
    Future<void> Function()? afterPop,
  }) async {
    await _runSingleNavigationTask(featureKey, () async {
      if (!mounted) {
        return;
      }
      unawaited(LogService().log('页面访问', logDetails));
      await Navigator.of(context).push(MaterialPageRoute(builder: pageBuilder));
      await afterPop?.call();
    });
  }

  void _handleSearchChanged(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == _searchQuery) {
      return;
    }
    setState(() {
      _searchQuery = normalized;
      if (_latestVisibleSections.isNotEmpty &&
          !_latestVisibleSections.any(
            (section) => section.id == _activeSectionId,
          )) {
        _activeSectionId = _latestVisibleSections.first.id;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensureActiveSectionStillValid();
      _scheduleSectionSync();
    });
  }

  void _handleContentScroll() {
    if (_isProgrammaticSectionScroll) {
      return;
    }
    _scheduleSectionSync();
  }

  void _scheduleSectionSync() {
    if (_pendingSectionSync) {
      return;
    }
    _pendingSectionSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingSectionSync = false;
      if (!mounted) {
        return;
      }
      _syncActiveSectionFromViewport();
    });
  }

  void _ensureActiveSectionStillValid() {
    if (_latestVisibleSections.isEmpty) {
      return;
    }
    if (_latestVisibleSections.any(
      (section) => section.id == _activeSectionId,
    )) {
      return;
    }
    setState(() {
      _activeSectionId = _latestVisibleSections.first.id;
    });
  }

  void _syncActiveSectionFromViewport() {
    if (_isProgrammaticSectionScroll) {
      return;
    }
    if (_latestVisibleSections.isEmpty) {
      return;
    }
    final viewportContext = _contentViewportKey.currentContext;
    if (viewportContext == null) {
      return;
    }
    final viewportObject = viewportContext.findRenderObject();
    if (viewportObject is! RenderBox) {
      return;
    }

    final metrics = <({String id, double top})>[];
    for (final section in _latestVisibleSections) {
      final sectionContext = _sectionKeyFor(section.id).currentContext;
      if (sectionContext == null) {
        continue;
      }
      final sectionObject = sectionContext.findRenderObject();
      if (sectionObject is! RenderBox) {
        continue;
      }
      metrics.add((
        id: section.id,
        top: sectionObject
            .localToGlobal(Offset.zero, ancestor: viewportObject)
            .dy,
      ));
    }

    if (metrics.isEmpty) {
      return;
    }

    String nextActiveId = metrics.first.id;
    if (_sectionAnchorOffset <= metrics.first.top) {
      nextActiveId = metrics.first.id;
    } else {
      for (var index = 0; index < metrics.length; index++) {
        final current = metrics[index];
        final nextTop = index + 1 < metrics.length
            ? metrics[index + 1].top
            : double.infinity;
        if (_sectionAnchorOffset >= current.top &&
            _sectionAnchorOffset < nextTop) {
          nextActiveId = current.id;
          break;
        }
      }
    }

    if (nextActiveId == _activeSectionId) {
      return;
    }
    setState(() {
      _activeSectionId = nextActiveId;
    });
  }

  Future<void> _scrollToSection(String sectionId) async {
    final targetContext = _sectionKeyFor(sectionId).currentContext;
    if (targetContext == null) {
      return;
    }
    final targetRenderObject = targetContext.findRenderObject();
    if (targetRenderObject == null ||
        !targetRenderObject.attached ||
        !_contentScrollController.hasClients) {
      return;
    }
    if (mounted && _activeSectionId != sectionId) {
      setState(() {
        _activeSectionId = sectionId;
      });
    }
    final token = ++_programmaticSectionScrollToken;
    _isProgrammaticSectionScroll = true;
    try {
      await _contentScrollController.position.ensureVisible(
        targetRenderObject,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        alignment: 0.02,
      );
    } finally {
      if (mounted && token == _programmaticSectionScrollToken) {
        _isProgrammaticSectionScroll = false;
      }
    }
  }

  GlobalKey _sectionKeyFor(String sectionId) {
    return _sectionKeys.putIfAbsent(
      sectionId,
      () => GlobalKey(debugLabel: 'service-section-$sectionId'),
    );
  }

  Map<String, _ServiceEntryAction> _buildEntryActions() {
    return {
      FunctionCenterEntryIds.courseTable: _buildSimpleEntryAction(
        entryId: FunctionCenterEntryIds.courseTable,
        logDetails: '从服务大厅进入课程表',
        pageBuilder: (context) => const SchedulePage(),
      ),
      FunctionCenterEntryIds.gradeQuery: _buildSimpleEntryAction(
        entryId: FunctionCenterEntryIds.gradeQuery,
        logDetails: '从服务大厅进入学业中心',
        pageBuilder: (context) => const GradePage(),
      ),
      FunctionCenterEntryIds.evaluationQuery: _buildSimpleEntryAction(
        entryId: FunctionCenterEntryIds.evaluationQuery,
        logDetails: '从服务大厅进入综合评测',
        pageBuilder: (context) => const XgEvaluationPage(),
      ),
      FunctionCenterEntryIds.campusMap: _buildSimpleEntryAction(
        entryId: FunctionCenterEntryIds.campusMap,
        logDetails: '从服务大厅进入校园地图',
        pageBuilder: (context) => const CampusMapPage(),
      ),
      FunctionCenterEntryIds.announcement: _buildSimpleEntryAction(
        entryId: FunctionCenterEntryIds.announcement,
        logDetails: '从服务大厅进入校园通知',
        pageBuilder: (context) => const PortalAnnouncementsListPage(),
      ),
    };
  }

  List<_ServiceSectionData> _buildSections() {
    final entryActions = _buildEntryActions();
    final sections = <_ServiceSectionData>[];

    for (final section in FunctionCenterCatalog.sortedSections()) {
      final runtimeEntries = <_ServiceEntryData>[];
      for (final entry in FunctionCenterCatalog.entriesOfSection(section.id)) {
        final action = entryActions[entry.id];
        if (action == null) {
          continue;
        }
        runtimeEntries.add(
          _ServiceEntryData(
            title: FunctionCenterCatalog.entryTitleOf(entry),
            subtitle: entry.subtitle,
            icon: FunctionCenterCatalog.entryIconOf(entry),
            color: FunctionCenterCatalog.entryColorOf(entry),
            isLoading: action.isLoading,
            isActive: true,
            onTap: action.onTap,
          ),
        );
      }
      if (runtimeEntries.isEmpty) {
        continue;
      }
      sections.add(
        _ServiceSectionData(
          id: section.id,
          title: section.title,
          accentColor: section.accentColor,
          entries: runtimeEntries,
        ),
      );
    }

    return sections;
  }

  List<_ServiceSectionData> _filterSections(
    List<_ServiceSectionData> sections,
  ) {
    if (_searchQuery.isEmpty) {
      return sections;
    }

    return sections
        .map((section) {
          final sectionMatches =
              section.title.toLowerCase().contains(_searchQuery) ||
              section.entries.any(
                (entry) =>
                    entry.searchText.toLowerCase().contains(_searchQuery),
              );
          if (!sectionMatches) {
            return null;
          }
          final entries = section.entries
              .where(
                (entry) =>
                    section.title.toLowerCase().contains(_searchQuery) ||
                    entry.searchText.toLowerCase().contains(_searchQuery),
              )
              .toList();
          return section.copyWith(entries: entries);
        })
        .whereType<_ServiceSectionData>()
        .toList();
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  '功能中心',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _NotificationButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PortalAnnouncementsListPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: TextField(
              controller: _searchController,
              onChanged: _handleSearchChanged,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
                height: 1.2,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索课表、成绩、公告、地图...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                  height: 1.2,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 42,
                  maxWidth: 42,
                  minHeight: 48,
                  maxHeight: 48,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  maxWidth: 40,
                  minHeight: 48,
                  maxHeight: 48,
                ),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : SizedBox(
                        width: 40,
                        height: 48,
                        child: Center(
                          child: IconButton(
                            tooltip: '清空搜索',
                            onPressed: _clearSearch,
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 40,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFD9E1F2)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _handleSearchChanged('');
  }

  Widget _buildSidebar(List<_ServiceSectionData> visibleSections) {
    return Container(
      width: 74,
      margin: const EdgeInsets.only(left: 8, right: 8),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: visibleSections.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: [
                for (final section in visibleSections)
                  _SidebarItem(
                    title: section.title,
                    accentColor: section.accentColor,
                    selected: section.id == _activeSectionId,
                    onTap: () => _scrollToSection(section.id),
                  ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(_ServiceSectionData section) {
    return Padding(
      key: _sectionKeyFor(section.id),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: section.accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            section.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: section.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPane(List<_ServiceSectionData> visibleSections) {
    final isEmpty = visibleSections.isEmpty;
    return Expanded(
      child: Container(
        key: _contentViewportKey,
        margin: EdgeInsets.only(right: isEmpty ? 0 : 12),
        child: isEmpty
            ? const Center(
                child: _FunctionsEmptyState(
                  key: ValueKey('functions-empty-state'),
                ),
              )
            : RefreshIndicator(
                onRefresh: _handlePullToRefresh,
                color: const Color(0xFF4F46E5),
                backgroundColor: Colors.white,
                displacement: 36,
                child: SingleChildScrollView(
                  controller: _contentScrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final section in visibleSections) ...[
                        _buildSectionHeader(section),
                        ...section.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FeatureCard(
                              icon: entry.icon,
                              title: entry.title,
                              subtitle: entry.subtitle,
                              color: entry.color,
                              onTap: entry.onTap,
                              trailingIcon: entry.trailingIcon,
                              isLoading: entry.isLoading,
                              isActive: entry.isActive,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sections = _buildSections();
    final visibleSections = _filterSections(sections);
    _latestVisibleSections = visibleSections;

    if (visibleSections.isNotEmpty &&
        !visibleSections.any((section) => section.id == _activeSectionId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.isEmpty) {
          return;
        }
        setState(() {
          _activeSectionId = visibleSections.first.id;
        });
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (visibleSections.isNotEmpty)
                    _buildSidebar(visibleSections),
                  _buildContentPane(visibleSections),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NotificationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 22,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String title;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.title,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 4,
              height: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: selected ? accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? accentColor : const Color(0xFF64748B),
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunctionsEmptyState extends StatelessWidget {
  const _FunctionsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 34,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '没有找到匹配功能',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '试试搜索其他分类、功能名称或服务描述。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceEntryAction {
  final bool isLoading;
  final VoidCallback onTap;

  const _ServiceEntryAction({required this.isLoading, required this.onTap});
}

class _ServiceSectionData {
  final String id;
  final String title;
  final Color accentColor;
  final List<_ServiceEntryData> entries;

  const _ServiceSectionData({
    required this.id,
    required this.title,
    required this.accentColor,
    required this.entries,
  });

  _ServiceSectionData copyWith({List<_ServiceEntryData>? entries}) {
    return _ServiceSectionData(
      id: id,
      title: title,
      accentColor: accentColor,
      entries: entries ?? this.entries,
    );
  }
}

class _ServiceEntryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool isActive;
  final IconData? trailingIcon = Icons.chevron_right_rounded;
  final VoidCallback onTap;

  const _ServiceEntryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
    this.isActive = true,
  });

  String get searchText => '$title $subtitle';
}
