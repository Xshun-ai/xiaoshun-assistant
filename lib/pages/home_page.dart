import 'dart:async';

import 'package:flutter/material.dart';

import '../login_page.dart';
import '../services/auth_service.dart';
import '../services/grade_service.dart';
import '../services/home_data_service.dart';
import '../services/log_service.dart';
import '../services/session_store.dart';
import '../services/sso_service.dart';
import '../services/token_refresh_service.dart';
import '../services/xg_http.dart';
import '../services/xg_session_coordinator.dart';
import 'home/tabs/functions_tab.dart';
import 'home/tabs/home_tab.dart';
import 'home/tabs/profile_tab.dart';
import 'home/widgets/home_bottom_nav_shell.dart';

class HomePageStateLogoutGuard {
  static void beginLogout() {
    _HomePageState._logoutInProgress = true;
  }

  static void endLogout() {
    _HomePageState._logoutInProgress = false;
  }
}

/// 首页容器 - 管理三个 Tab 的切换和学校会话预热。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static bool _logoutInProgress = false;

  int _currentIndex = 0;
  int _homeRefreshTick = 0;
  late final PageController _pageController;
  Future<void>? _startupBootstrapFuture;
  Future<void>? _xgPreloadFuture;
  bool _sessionInvalidDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _logoutInProgress = false;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupBootstrap());
    });
  }

  Future<void> _runStartupBootstrap() async {
    final inFlight = _startupBootstrapFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final task = _runStartupBootstrapInternal();
    _startupBootstrapFuture = task;
    try {
      await task;
    } finally {
      if (identical(_startupBootstrapFuture, task)) {
        _startupBootstrapFuture = null;
      }
    }
  }

  Future<void> _runStartupBootstrapInternal() async {
    if (!mounted || _logoutInProgress) {
      return;
    }

    unawaited(_logAppStart());
    await _recoverSessionAndWarmup();
  }

  Future<void> _recoverSessionAndWarmup() async {
    if (_logoutInProgress) {
      return;
    }

    final store = SessionStore();
    final token = await store.getAccessToken();
    TokenRefreshResult? refreshResult;
    var sessionReady = false;

    if (token == null || token.isEmpty) {
      refreshResult = await TokenRefreshService().tryRefreshToken();
      if (refreshResult.isRefreshed) {
        sessionReady = true;
      }
    } else {
      final validation = await AuthService().validateAccessToken(token);
      if (validation.isValid) {
        sessionReady = true;
      } else if (validation.isNetworkError) {
        return;
      } else {
        refreshResult = await TokenRefreshService().tryRefreshToken();
        if (refreshResult.isRefreshed) {
          sessionReady = true;
        }
      }
    }

    if (!sessionReady) {
      if (refreshResult?.isNetworkUnavailable == true) {
        return;
      }
      if (refreshResult?.isInvalidCredentials == true) {
        await _promptLoginExpiredAndLogout();
      }
      return;
    }

    await _refreshUserInfoSilently();
    await _preloadUserInfo();
    _preloadXgModules();
    _preloadOtherFeaturePages();
    _refreshHomeTab();
  }

  Future<void> _refreshUserInfoSilently() async {
    try {
      final store = SessionStore();
      final token = await store.getAccessToken();
      if (token == null || token.isEmpty) {
        return;
      }
      final auth = AuthService();
      final info = await auth.getUserInfo(token);
      await store.saveUserInfo(info);
      await store.saveDisplayName(info.displayName);
      await store.saveUserInfoDetails(
        college: info.ouName,
        className: info.className,
      );
    } catch (e) {
      debugPrint('Refresh user info error: $e');
    }
  }

  Future<void> _promptLoginExpiredAndLogout() async {
    if (!mounted || _sessionInvalidDialogVisible || _logoutInProgress) {
      return;
    }
    _sessionInvalidDialogVisible = true;
    try {
      await SessionStore().clearAuthSession();
      await SessionStore().clearPassword();
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('登录状态已失效'),
          content: const Text('检测到学校账号密码已失效，请重新登录。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('重新登录'),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 320),
        ),
        (route) => false,
      );
    } finally {
      _sessionInvalidDialogVisible = false;
    }
  }

  void _preloadXgModules() {
    final inFlight = _xgPreloadFuture;
    if (inFlight != null) {
      return;
    }

    final task = () async {
      try {
        final store = SessionStore();
        final token = await store.getAccessToken();
        if (token == null || token.isEmpty) return;

        final username = await store.getUsername();
        if (username == null || username.isEmpty) return;
        if (!XgHttp.instance.initialized) {
          await XgHttp.instance.init();
        }
        final didPreload = await XgSessionCoordinator.instance
            .preloadAvailableModules(source: 'home_preload');
        if (didPreload) {
          await LogService().log('智慧学工', '首页已完成智慧学工基础会话预热');
        }
      } catch (e) {
        await LogService().log('智慧学工', '首页预热智慧学工会话失败: $e');
      }
    }();

    _xgPreloadFuture = task;
    task.whenComplete(() {
      if (identical(_xgPreloadFuture, task)) {
        _xgPreloadFuture = null;
      }
    });
  }

  void _preloadOtherFeaturePages() {
    () async {
      try {
        final store = SessionStore();
        final username = await store.getUsername();
        if (username == null || username.isEmpty) return;

        String? ydjwToken = await store.getYdjwToken();
        if (!SsoService.isValidMobileToken(ydjwToken) &&
            ydjwToken != null &&
            ydjwToken.isNotEmpty) {
          await store.clearYdjwToken();
          ydjwToken = null;
        }

        try {
          final gradeService = GradeService();
          await gradeService.fetchAllGrades();
          await LogService().log('成绩', '首页已预热成绩数据');
        } catch (e) {
          await LogService().log('成绩', '首页预热成绩数据失败: $e');
        }

        try {
          final homeDataService = HomeDataService();
          await homeDataService.warmFullScheduleCache();
          await LogService().log('课表', '首页已预热完整课表缓存');
        } catch (e) {
          await LogService().log('课表', '首页预热完整课表缓存失败: $e');
        }
      } catch (e) {
        await LogService().log('预热', '首页预热其他功能页失败: $e');
      }
    }();
  }

  Future<void> _preloadUserInfo() async {
    try {
      final store = SessionStore();
      final token = await store.getAccessToken();
      if (token != null) {
        final auth = AuthService();
        final info = await auth.getUserInfo(token);
        await store.saveDisplayName(info.displayName);
        await store.saveUserInfoDetails(
          college: info.ouName,
          className: info.className,
        );
      }
    } catch (e) {
      debugPrint('Preload user info error: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_logoutInProgress) {
      return;
    }
    _dismissKeyboard();
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (_logoutInProgress) {
      return;
    }
    _dismissKeyboard();
    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      _refreshHomeTab();
    }

    String moduleName = '未知';
    switch (index) {
      case 0:
        moduleName = '首页';
        break;
      case 1:
        moduleName = '功能';
        break;
      case 2:
        moduleName = '我的';
        break;
    }
    LogService().log('页面访问', '打开模块: $moduleName');
  }

  void _refreshHomeTab() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        debugPrint('[首页刷新] Tab切换到首页，触发后台刷新');
        setState(() {
          _homeRefreshTick++;
        });
      }
    });
  }

  Future<void> _logAppStart() async {
    try {
      await LogService().log('应用启动', '用户打开应用');
    } catch (e) {
      debugPrint('记录启动日志失败: $e');
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _logoutFromProfileTab() async {
    if (_logoutInProgress || !mounted) {
      return;
    }

    HomePageStateLogoutGuard.beginLogout();
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
          transitionDuration: const Duration(milliseconds: 320),
        ),
        (route) => false,
      );
    } finally {
      _HomePageState._logoutInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF5F7FA),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const PageScrollPhysics(),
        children: [
          HomeTab(refreshTick: _homeRefreshTick),
          FunctionsTab(onRefresh: _runStartupBootstrap),
          ProfileTab(
            waitForSessionReady: _runStartupBootstrap,
            onLogoutRequested: _logoutFromProfileTab,
          ),
        ],
      ),
      bottomNavigationBar: HomeBottomNavShell(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
