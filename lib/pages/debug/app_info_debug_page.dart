import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../constants/app_colors.dart';
import '../../services/session_store.dart';
import '../../ui/components/app_card.dart';
import 'debug_shared.dart';

class AppInfoDebugPage extends StatefulWidget {
  const AppInfoDebugPage({super.key});

  @override
  State<AppInfoDebugPage> createState() => _AppInfoDebugPageState();
}

class _AppInfoDebugPageState extends State<AppInfoDebugPage> {
  final SessionStore _sessionStore = SessionStore();

  PackageInfo? _packageInfo;
  String _loginUser = '-';
  String _displayName = '-';

  @override
  void initState() {
    super.initState();
    unawaited(_loadDebugInfo());
  }

  Future<void> _loadDebugInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final user = await _sessionStore.getUsername();
      final displayName = await _sessionStore.getDisplayName();

      if (!mounted) {
        return;
      }

      setState(() {
        _packageInfo = packageInfo;
        _loginUser = user?.trim().isNotEmpty == true ? user!.trim() : '-';
        _displayName = displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : '-';
      });
    } catch (e) {
      debugPrint('加载应用信息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = _packageInfo;
    final versionText = packageInfo == null
        ? '加载中...'
        : '${packageInfo.version}+${packageInfo.buildNumber}';
    final deviceText =
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

    return Scaffold(
      key: const Key('debug-app-info-page'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '应用与环境',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            key: const Key('debug-app-info-refresh'),
            onPressed: _loadDebugInfo,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新信息',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          const DebugSectionTitle(
            title: '应用与环境',
            subtitle: '只读展示当前构建、账号和设备平台。',
          ),
          AppCard(
            key: const Key('debug-section-env'),
            child: Column(
              children: [
                DebugInfoRow(label: '版本', value: versionText),
                DebugInfoRow(label: '登录账号', value: _loginUser),
                DebugInfoRow(label: '显示名称', value: _displayName),
                DebugInfoRow(label: '设备平台', value: deviceText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
