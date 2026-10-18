import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/build_config.dart';
import '../services/log_service.dart';
import '../services/auth_service.dart';
import '../login_page.dart';
import 'home_page.dart';
import 'debug_page.dart';
import '../ui/components/app_page_app_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';
  int _debugTapCount = 0;
  Timer? _debugTapResetTimer;

  @override
  void initState() {
    super.initState();
    LogService().log('页面访问', '打开功能: 设置');
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
        });
      }
    } catch (e) {
      debugPrint('Get version error: $e');
    }
  }

  @override
  void dispose() {
    _debugTapResetTimer?.cancel();
    super.dispose();
  }

  void _resetDebugTapState() {
    _debugTapResetTimer?.cancel();
    _debugTapResetTimer = null;
    _debugTapCount = 0;
  }

  Future<void> _handleVersionTap() async {
    if (!kDebugMode || BuildConfig.debugPanelPassword.isEmpty) {
      return;
    }

    _debugTapResetTimer?.cancel();
    _debugTapResetTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _debugTapCount = 0;
      });
    });

    final nextCount = _debugTapCount + 1;
    if (mounted) {
      setState(() {
        _debugTapCount = nextCount;
      });
    } else {
      _debugTapCount = nextCount;
    }

    if (_debugTapCount < 5) {
      return;
    }

    _resetDebugTapState();
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => const _DebugPasswordDialog(),
    );
    if (verified != true || !mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DebugPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: const AppPageAppBar(title: '设置'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _SettingsItem(
                    icon: Icons.logout_rounded,
                    title: '退出登录',
                    onTap: () async {
                      final rootContext = context;
                      showDialog(
                        context: rootContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('确认退出'),
                          content: const Text('确定要退出登录吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                HomePageStateLogoutGuard.beginLogout();

                                // 使用 AuthService 执行完整退出流程
                                await AuthService().logout();

                                if (!mounted) return;

                                if (rootContext.mounted) {
                                  Navigator.of(rootContext).pushAndRemoveUntil(
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => const LoginPage(),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) => FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                      transitionDuration: const Duration(
                                        milliseconds: 320,
                                      ),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                              child: const Text('退出'),
                            ),
                          ],
                        ),
                      );
                    },
                    textColor: Colors.redAccent,
                    iconColor: Colors.redAccent,
                    showChevron: false,
                  ),
                ],
              ),
            ),
          ),
          if (_version.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Center(
                child: GestureDetector(
                  key: const Key('settings-version-trigger'),
                  behavior: HitTestBehavior.opaque,
                  onTap: kDebugMode ? _handleVersionTap : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      '版本 v$_version',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DebugPasswordDialog extends StatefulWidget {
  const _DebugPasswordDialog();

  @override
  State<_DebugPasswordDialog> createState() => _DebugPasswordDialogState();
}

class _DebugPasswordDialogState extends State<_DebugPasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscureText = true;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!kDebugMode) {
      Navigator.of(context).pop(false);
      return;
    }

    final input = _controller.text.trim();
    if (input == BuildConfig.debugPanelPassword) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _errorText = '调试密码错误';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入调试密码'),
      content: TextField(
        key: const Key('debug-password-field'),
        controller: _controller,
        obscureText: _obscureText,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '请输入密码',
          errorText: _errorText,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
            icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          ),
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() {
              _errorText = null;
            });
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('debug-password-submit'),
          onPressed: _submit,
          child: const Text('进入'),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;
  final bool showChevron;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
    this.iconColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (iconColor ?? Theme.of(context).primaryColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? Theme.of(context).primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? Colors.black87,
                  ),
                ),
                const Spacer(),
                if (showChevron)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[300],
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
