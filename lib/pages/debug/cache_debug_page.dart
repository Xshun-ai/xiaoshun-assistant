import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../login_page.dart';
import '../../services/auth_service.dart';
import '../../ui/components/app_card.dart';
import '../../ui/components/custom_toast.dart';
import 'debug_shared.dart';

class CacheDebugPage extends StatefulWidget {
  const CacheDebugPage({super.key});

  @override
  State<CacheDebugPage> createState() => _CacheDebugPageState();
}

class _CacheDebugPageState extends State<CacheDebugPage> {
  bool _isBusy = false;

  Future<void> _clearAllCacheAndExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有缓存数据'),
        content: const Text('这会清除当前账号所有缓存与会话，并立即返回登录界面，等同于退出登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认清空'),
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
      await AuthService().logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 240),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      CustomToast.error(context, message: '清空失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('debug-cache-tools-page'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '缓存与会话',
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
                title: '缓存与会话',
                subtitle: '集中处理缓存、认证会话和登录态相关的本地调试操作。',
              ),
              AppCard(
                key: const Key('debug-section-local-actions'),
                child: Column(
                  children: [
                    DebugActionTile(
                      tileKey: const Key('debug-action-clear-all-cache'),
                      title: '清空所有缓存数据',
                      subtitle: '清除缓存后立即返回登录页，效果等同于退出登录。',
                      onTap: _isBusy ? null : _clearAllCacheAndExit,
                      icon: Icons.delete_forever_outlined,
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
