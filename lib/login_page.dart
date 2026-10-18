import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/campus_access_service.dart';
import 'services/session_store.dart';
import 'services/log_service.dart';
import 'services/xg_http.dart';
import 'features/auth/widgets/mobile_login_layout.dart';
import 'pages/home_page.dart';
import 'ui/components/custom_toast.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isObscure = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  String? _captchaImageBase64;
  String? _captchaCode;
  bool _loading = false;
  final CampusAccessService _campusAccessService = CampusAccessService();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final store = SessionStore();
    final username = await store.getUsername();
    final password = await store.getPassword();

    if (username != null) _usernameController.text = username;
    if (password != null) {
      _passwordController.text = password;
    }
  }

  Future<void> _refreshCaptcha() async {
    try {
      final auth = AuthService();
      final captcha = await auth.fetchCaptcha();
      if (!mounted) return;
      setState(() {
        _captchaImageBase64 = captcha['captcha'];
        _captchaCode = captcha['code'];
        _captchaController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      CustomToast.error(context, message: '验证码刷新失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MobileLoginLayout(
        formKey: _formKey,
        usernameController: _usernameController,
        passwordController: _passwordController,
        captchaController: _captchaController,
        isObscure: _isObscure,
        loading: _loading,
        captchaImageBase64: _captchaImageBase64,
        onToggleObscure: () => setState(() => _isObscure = !_isObscure),
        onRefreshCaptcha: _refreshCaptcha,
        onLogin: _handleLogin,
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    try {
      final auth = AuthService();
      final res = await auth.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        capCode: _captchaCode,
        capText: _captchaController.text.isEmpty
            ? null
            : _captchaController.text.trim(),
      );

      if (res.success) {
        final store = SessionStore();
        final currentUsername = _usernameController.text.trim();
        final previousUsername = await store.getUsername();

        if (previousUsername != null &&
            previousUsername.isNotEmpty &&
            previousUsername != currentUsername) {
          await auth.clearUserScopedSessionForSwitch();
        }

        await store.saveAccessToken(res.accessToken!);
        await store.saveUsername(currentUsername);
        await store.setRememberPassword(true);
        await store.setAutoLogin(true);
        await store.savePassword(_passwordController.text);
        await XgHttp.instance.resetSessionArtifacts(source: 'login_success');

        // 获取用户信息并写入本地缓存
        try {
          final userInfo = await auth.getUserInfo(res.accessToken!);
          await store.saveUserInfo(userInfo);
          await store.saveDisplayName(userInfo.displayName);
          await store.saveUserInfoDetails(
            college: userInfo.ouName,
            className: userInfo.className,
          );
        } catch (e) {
          debugPrint('DEBUG: 获取用户信息失败: $e');
        }

        unawaited(
          LogService().log(
            '登录',
            '登录成功，准备跳转首页',
          ),
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const HomePage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      } else {
        if (res.error == 'network_error') {
          final eligibility = await _campusAccessService
              .evaluateCachedSessionEligibility(
                _usernameController.text.trim(),
                _passwordController.text,
              );
          if (eligibility.canEnter) {
            final enteredWithCachedSession =
                await _enterWithCachedSessionDirectly();
            if (enteredWithCachedSession) {
              return;
            }
          } else {
            await _showCachedSessionUnavailableDialog(
              eligibility.reason ?? '请先在联网状态下成功登录一次。',
            );
            return;
          }
        }

        await LogService().log(
          '登录',
          '登录失败: ${res.error}',
        );
        if (res.captchaImageBase64 != null) {
          setState(() {
            _captchaImageBase64 = res.captchaImageBase64;
            _captchaCode = res.captchaCode;
            _captchaController.clear();
          });
        }

        if (!mounted) return;
        CustomToast.error(context, message: _mapError(res.error));
      }
    } catch (e) {
      await LogService().log(
        '登录',
        '登录异常: $e',
      );
      if (!mounted) return;
      final message = CampusAccessService.toUserFacingErrorMessage(
        e,
        fallback: '登录失败，请稍后重试',
        networkMessage: '网络连接异常，请稍后重试',
      );
      CustomToast.error(context, message: message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<bool> _enterWithCachedSessionDirectly() async {
    if (!mounted) {
      return true;
    }

    CustomToast.warning(context, message: '校园网服务暂不可用，已进入应用并继续使用本地缓存数据');

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
    return true;
  }

  Future<void> _showCachedSessionUnavailableDialog(String message) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('暂时无法进入应用'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  String _mapError(String? err) {
    switch (err) {
      case 'Bad credentials':
        return '用户名或密码错误';
      case 'invalid_captcha':
        return '验证码错误';
      case 'login_failed_will_lock_1_5':
        return '登录失败1次，5次将锁定账号';
      case 'login_failed_will_lock_2_5':
        return '登录失败2次，5次将锁定账号';
      case 'login_failed_will_lock_3_5':
        return '登录失败3次，5次将锁定账号';
      case 'login_failed_will_lock_4_5':
        return '登录失败4次，5次将锁定账号';
      case 'login_failed_user_locked':
        return '账户因登录失败次数过多被锁定。请在30分钟后重试。';
      case 'network_error':
        return '无法连接校园网，请稍后重试';
      default:
        return '登录失败';
    }
  }
}
