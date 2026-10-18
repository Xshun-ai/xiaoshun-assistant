import 'package:flutter/material.dart';

import '../../../models/xg_activity.dart';
import '../../../services/log_service.dart';
import '../../../utils/role_helper.dart';
import '../../../utils/loadable_state.dart';
import '../../../services/xg_activity_service.dart';
import '../../../constants/app_colors.dart';
import '../../../ui/components/app_page_app_bar.dart';
import '../widgets/xg_action_feedback.dart';
import '../widgets/xg_activity_apply_dialog.dart';
import '../widgets/xg_activity_apply_widgets.dart';
import '../widgets/xg_activity_detail_cards.dart';

class XgActivityDetailPage extends StatefulWidget {
  final XgActivity activity;

  const XgActivityDetailPage({super.key, required this.activity});

  @override
  State<XgActivityDetailPage> createState() => _XgActivityDetailPageState();
}

class _XgActivityDetailPageState extends State<XgActivityDetailPage>
    with LoadableStateMixin {
  bool _hasActionTaken = false;

  // 活动服务实例
  final XgActivityService _activityService = XgActivityService();

  @override
  void initState() {
    super.initState();
    _initDioAndLoadData();
  }

  Future<void> _doApply(String cycd) async {
    showXgActionLoadingDialog(context);

    final roleName = getRoleName(cycd);
    final activityName = widget.activity.name;

    final result = await _activityService.applyForActivity(
      activityId: widget.activity.id,
      cycd: cycd,
      activityName: activityName,
      roleName: roleName,
      scene: '详情页',
    );

    if (!mounted) return;

    hideXgActionLoadingDialog(context);

    if (result.success) {
      if (!mounted) return;

      await LogService().log('智慧学工', '详情页报名成功: $activityName (身份: $roleName)');

      if (!mounted) return;

      showXgSuccessSnackBar(context, message: '报名成功！');
      _hasActionTaken = true;
      // 刷新详情
      await loadData<Map<String, dynamic>>(
        key: 'detail',
        loader: () => _activityService.fetchActivityDetail(widget.activity.id),
      );
    } else {
      if (!mounted) return;
      showXgErrorSnackBar(context, message: result.message);
    }
  }

  Future<void> _showApplyConfirmDialog() async {
    final selectedRole = await showXgActivityApplyDialog(
      context: context,
      activity: widget.activity,
    );

    if (!mounted || selectedRole == null) {
      return;
    }

    await _doApply(selectedRole);
  }

  Future<void> _initDioAndLoadData() async {
    await loadData<Map<String, dynamic>>(
      key: 'detail',
      loader: () async {
        return await _activityService.fetchActivityDetail(widget.activity.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppPageAppBar(
        title: '活动详情',
        leading: BackButton(
          onPressed: () => Navigator.pop(context, _hasActionTaken),
        ),
      ),
      body: _buildBody(),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    return buildLoadable<Map<String, dynamic>>(
      key: 'detail',
      errorMessage: '获取失败，请稍后重试',
      builder: (detailData) {
        final description = detailData['HDJS'] ?? '暂无介绍';
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),
              XgActivityDetailTitleCard(
                activity: widget.activity,
                detail: detailData,
              ),
              XgActivityDetailInfoCard(
                activity: widget.activity,
                detail: detailData,
              ),
              XgActivityDescriptionCard(description: description),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final detailData = getLoadable<Map<String, dynamic>>('detail').data;
    final detail = detailData ?? {};
    // 检查是否已报名 (结合详情接口的HASAPPLY和列表接口的SHZT_DISPLAY)
    final hasApply =
        detail['HASAPPLY'] == 'true' ||
        (detail['HASAPPLY'] != null &&
            detail['HASAPPLY'].toString().isNotEmpty);
    final statusDisplay =
        detail['SHZT_DISPLAY'] ?? widget.activity.statusDisplay;
    final isApplied =
        hasApply || (statusDisplay != null && statusDisplay.contains('已报名'));

    // 检查不可报名原因
    final cannotApplyReason = detail['CANNOTAPPLY'];

    return XgActivityDetailBottomBar(
      isApplied: isApplied,
      isExpired: widget.activity.isExpired,
      isFull: widget.activity.isFull,
      cannotApplyReason: cannotApplyReason?.toString(),
      onApply: _showApplyConfirmDialog,
    );
  }
}
