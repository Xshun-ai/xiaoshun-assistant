import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/log_service.dart';
import '../../ui/components/app_card.dart';
import '../../ui/components/custom_toast.dart';
import 'debug_shared.dart';

class LogToolsDebugPage extends StatefulWidget {
  const LogToolsDebugPage({super.key});

  @override
  State<LogToolsDebugPage> createState() => _LogToolsDebugPageState();
}

class _LogToolsDebugPageState extends State<LogToolsDebugPage> {
  final LogService _logService = LogService();
  bool _isBusy = false;

  Future<void> _previewLogs() async {
    setState(() {
      _isBusy = true;
    });
    try {
      final logs = await _logService.getRecentLogs(days: 7);
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '最近日志（7天）',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        logs.isEmpty ? '暂无日志' : logs,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      CustomToast.error(context, message: '读取日志失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _copyLogs() async {
    setState(() {
      _isBusy = true;
    });
    try {
      final logs = await _logService.getRecentLogs(days: 7);
      await Clipboard.setData(ClipboardData(text: logs));
      if (!mounted) {
        return;
      }
      CustomToast.success(
        context,
        message: logs.isEmpty ? '暂无日志，已复制空内容' : '日志已复制',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      CustomToast.error(context, message: '复制日志失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空本地日志'),
        content: const Text('这会删除本地 runtime 日志文件，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _logService.clearLogs();
      if (!mounted) {
        return;
      }
      CustomToast.success(context, message: '本地日志已清空');
    } catch (e) {
      if (!mounted) {
        return;
      }
      CustomToast.error(context, message: '清空日志失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('debug-log-tools-page'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '日志工具',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              const DebugSectionTitle(
                title: '日志工具',
                subtitle: '集中处理最近运行日志的查看、复制和清理操作。',
              ),
              AppCard(
                key: const Key('debug-section-local-actions'),
                child: Column(
                  children: [
                    DebugActionTile(
                      tileKey: const Key('debug-action-preview-logs'),
                      title: '查看最近日志',
                      subtitle: '预览最近 7 天 runtime 日志。',
                      onTap: _isBusy ? null : _previewLogs,
                      icon: Icons.visibility_outlined,
                    ),
                    const Divider(height: 1),
                    DebugActionTile(
                      tileKey: const Key('debug-action-copy-logs'),
                      title: '复制最近日志',
                      subtitle: '将最近 7 天日志复制到剪贴板。',
                      onTap: _isBusy ? null : _copyLogs,
                      icon: Icons.copy_rounded,
                    ),
                    const Divider(height: 1),
                    DebugActionTile(
                      tileKey: const Key('debug-action-clear-logs'),
                      title: '清空本地日志',
                      subtitle: '删除 runtime 日志文件，不可恢复。',
                      onTap: _isBusy ? null : _clearLogs,
                      icon: Icons.delete_outline_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
          if (_isBusy) const DebugBusyIndicator(),
        ],
      ),
    );
  }
}
